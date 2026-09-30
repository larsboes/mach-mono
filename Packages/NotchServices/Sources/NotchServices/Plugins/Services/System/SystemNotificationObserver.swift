//
//  SystemNotificationObserver.swift
//  machNotch
//
//  Observes macOS system notifications from other apps via Accessibility API.
//  Monitors UserNotificationCenter.app for notification banners and extracts content.
//
//  An AXObserver wakes us when a banner window appears, so an idle Mac costs
//  nothing. It cannot be the only trigger: a banner arriving while another is
//  still on screen reuses the same AX window and fires no notification at all
//  (measured on macOS 26.6). So a wake starts a short scan burst that runs only
//  while a banner is actually on screen, and stops as soon as one is not.
//

import AppKit
import ApplicationServices

@MainActor
@Observable
final class SystemNotificationObserver: SystemNotificationObserverProtocol {
    private(set) var isObserving = false

    private let notificationManager: any NotificationServiceProtocol
    private var knownHashes: Set<Int> = []
    private var hashCleanupTask: Task<Void, Never>?

    private var axObservers: [pid_t: AXObserver] = [:]
    private var scanTask: Task<Void, Never>?
    private var workspaceTokens: [NSObjectProtocol] = []
    /// Only ever compared against itself to detect "did this scan find anything".
    private var reportCount = 0

    nonisolated static let notificationCenterBundleIDs = [
        "com.apple.UserNotificationCenter",
        "com.apple.notificationcenterui",
    ]

    /// Cadence of the burst that follows a wake. Fast enough to catch a banner
    /// swapped in place, which is the case the AXObserver cannot report.
    private static let scanInterval: Duration = .milliseconds(500)
    /// Stop the burst after this many consecutive scans find no banner window.
    private static let emptyScansBeforeIdle = 3
    /// Hard ceiling on one burst. `notificationCenterApps()` also matches any app
    /// whose localized name contains "notification", so an unrelated app holding
    /// a window open must not be able to pin the burst on forever — that would
    /// be a permanent 2 Hz scan, worse than the poll this replaced.
    private static let maxBurstDuration: Duration = .seconds(30)

    init(notificationManager: any NotificationServiceProtocol) {
        self.notificationManager = notificationManager
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            scanTask?.cancel()
            hashCleanupTask?.cancel()
            teardownAXObservers()
            workspaceTokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        }
    }

    // MARK: - Lifecycle

    func startObserving() {
        guard !isObserving else { return }
        guard AXIsProcessTrusted() else {
            // Defer the system dialog so it doesn't interrupt the notch startup animation
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                let options: NSDictionary = ["AXTrustedCheckOptionPrompt": false]
                _ = AXIsProcessTrustedWithOptions(options)
            }
            return
        }

        isObserving = true
        attachAXObservers()
        observeWorkspaceLifecycle()
        startHashCleanup()
        // A banner may already be up when the plugin activates.
        wake()
    }

    func stopObserving() {
        isObserving = false
        scanTask?.cancel()
        scanTask = nil
        hashCleanupTask?.cancel()
        hashCleanupTask = nil
        teardownAXObservers()
        workspaceTokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceTokens.removeAll()
        knownHashes.removeAll()
    }

    // MARK: - AX Observers

    private func attachAXObservers() {
        teardownAXObservers()

        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let observer = Unmanaged<SystemNotificationObserver>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { observer.wake() }
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for app in Self.notificationCenterApps() {
            let pid = app.processIdentifier
            var observer: AXObserver?
            guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { continue }

            let axApp = AXUIElementCreateApplication(pid)
            // Both fire for a newly created banner; the content dedupe below
            // absorbs the duplicate.
            for name in [kAXWindowCreatedNotification, kAXCreatedNotification] {
                AXObserverAddNotification(observer, axApp, name as CFString, refcon)
            }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
            axObservers[pid] = observer
        }
    }

    private func teardownAXObservers() {
        for observer in axObservers.values {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        axObservers.removeAll()
    }

    /// Notification Center can restart; re-attach when the process set changes.
    private func observeWorkspaceLifecycle() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                    .bundleIdentifier
                guard let bundleID, Self.notificationCenterBundleIDs.contains(bundleID) else { return }
                MainActor.assumeIsolated {
                    guard let self, self.isObserving else { return }
                    self.attachAXObservers()
                }
            }
            workspaceTokens.append(token)
        }
    }

    // MARK: - Scan Burst

    /// Called by the AXObserver, and once at start. Runs a scan burst until the
    /// banner window goes away, then returns the app to zero background cost.
    private func wake() {
        guard isObserving, scanTask == nil else { return }
        scanTask = Task { @MainActor [weak self] in
            var deadline = ContinuousClock.now + Self.maxBurstDuration
            var emptyScans = 0
            while !Task.isCancelled, let self, self.isObserving {
                let reportsBefore = self.reportCount
                let sawBanner = self.scanNotificationBanners()

                emptyScans = sawBanner ? 0 : emptyScans + 1
                if emptyScans >= Self.emptyScansBeforeIdle { break }
                // Real notification traffic earns more time; a window that just
                // sits there does not, so the ceiling still bites.
                if self.reportCount > reportsBefore {
                    deadline = ContinuousClock.now + Self.maxBurstDuration
                } else if ContinuousClock.now >= deadline {
                    break
                }

                try? await Task.sleep(for: Self.scanInterval)
            }
            self?.scanTask = nil
        }
    }

    private func startHashCleanup() {
        hashCleanupTask?.cancel()
        hashCleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { break }
                // Trim hash set to prevent unbounded growth
                if let self = self, self.knownHashes.count > 500 {
                    self.knownHashes.removeAll()
                }
            }
        }
    }

    // MARK: - Dedupe

    /// Returns false when the notification was already reported.
    func recordIfNew(_ notification: NotchNotification) -> Bool {
        knownHashes.insert(notification.hashValue).inserted
    }

    func report(_ notification: NotchNotification) {
        reportCount += 1
        notificationManager.addNotification(notification)
    }
}
