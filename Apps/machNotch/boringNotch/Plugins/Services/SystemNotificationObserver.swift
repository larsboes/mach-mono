//
//  SystemNotificationObserver.swift
//  boringNotch
//
//  Observes macOS system notifications from other apps via Accessibility API.
//  Monitors UserNotificationCenter.app for notification banners and extracts content.
//

import AppKit
import ApplicationServices

@MainActor
@Observable
final class SystemNotificationObserver: SystemNotificationObserverProtocol {
    private(set) var isObserving = false

    private let notificationManager: any NotificationServiceProtocol
    private var pollTask: Task<Void, Never>?
    private var knownHashes: Set<Int> = []
    private var hashCleanupTask: Task<Void, Never>?

    private static let notificationCenterBundleID = "com.apple.UserNotificationCenter"
    private static let pollInterval: UInt64 = 2 * 1_000_000_000 // 2 seconds
    private static let dedupeWindowSeconds: TimeInterval = 5

    init(notificationManager: any NotificationServiceProtocol) {
        self.notificationManager = notificationManager
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            pollTask?.cancel()
            hashCleanupTask?.cancel()
        }
    }

    func startObserving() {
        guard !isObserving else { return }
        guard AXIsProcessTrusted() else {
            print("[SystemNotificationObserver] Accessibility not trusted — requesting permission")
            let options: NSDictionary = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ]
            AXIsProcessTrustedWithOptions(options)
            return
        }

        isObserving = true
        startPolling()
        startHashCleanup()
    }

    func stopObserving() {
        isObserving = false
        pollTask?.cancel()
        pollTask = nil
        hashCleanupTask?.cancel()
        hashCleanupTask = nil
        knownHashes.removeAll()
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.pollInterval)
                if Task.isCancelled { break }
                self?.pollNotificationBanners()
            }
        }
    }

    private func startHashCleanup() {
        hashCleanupTask?.cancel()
        hashCleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000) // 30s
                if Task.isCancelled { break }
                // Trim hash set to prevent unbounded growth
                if let self = self, self.knownHashes.count > 500 {
                    self.knownHashes.removeAll()
                }
            }
        }
    }

    private func pollNotificationBanners() {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.notificationCenterBundleID
        ).first else { return }

        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        guard let windows = axAttribute(axApp, kAXWindowsAttribute) as? [AXUIElement] else {
            return
        }

        for window in windows {
            extractNotificationsFromElement(window)
        }
    }

    // MARK: - AX Tree Traversal

    private func extractNotificationsFromElement(_ element: AXUIElement) {
        let role = axAttribute(element, kAXRoleAttribute) as? String
        let subrole = axAttribute(element, kAXSubroleAttribute) as? String

        // Notification banners are typically AXGroup or AXNotificationCenter elements
        if role == kAXGroupRole as String || subrole == "AXNotificationCenterAlert" || subrole == "AXNotificationCenterBanner" {
            if let notification = extractNotificationContent(from: element) {
                let hash = notification.hashValue
                guard !knownHashes.contains(hash) else { return }
                knownHashes.insert(hash)
                notificationManager.addNotification(notification)
                return
            }
        }

        // Recursively traverse children
        guard let children = axAttribute(element, kAXChildrenAttribute) as? [AXUIElement] else {
            return
        }

        for child in children {
            extractNotificationsFromElement(child)
        }
    }

    private func extractNotificationContent(from element: AXUIElement) -> NotchNotification? {
        // Try to extract title and body from the notification element's children
        var title: String?
        var body: String?
        var appName: String?

        // Try direct attributes first
        title = axAttribute(element, kAXTitleAttribute) as? String
        body = axAttribute(element, kAXDescriptionAttribute) as? String

        // If no direct attributes, traverse children for static text elements
        if title == nil || body == nil {
            if let children = axAttribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                var staticTexts: [String] = []
                collectStaticTexts(from: children, into: &staticTexts)

                // Typically: [app name, title, body] or [title, body]
                switch staticTexts.count {
                case 1:
                    title = title ?? staticTexts[0]
                case 2:
                    title = title ?? staticTexts[0]
                    body = body ?? staticTexts[1]
                case 3...:
                    appName = staticTexts[0]
                    title = title ?? staticTexts[1]
                    body = body ?? staticTexts[2]
                default:
                    break
                }
            }
        }

        guard let notifTitle = title, !notifTitle.isEmpty else { return nil }

        return NotchNotification(
            title: notifTitle,
            message: body ?? "",
            category: .app,
            sourceApp: appName
        )
    }

    private func collectStaticTexts(from elements: [AXUIElement], into texts: inout [String]) {
        for element in elements {
            let role = axAttribute(element, kAXRoleAttribute) as? String
            if role == kAXStaticTextRole as String {
                if let value = axAttribute(element, kAXValueAttribute) as? String, !value.isEmpty {
                    texts.append(value)
                }
            }
            // Recurse into children (max 3 levels deep to avoid excessive traversal)
            if texts.count < 5, let children = axAttribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                collectStaticTexts(from: children, into: &texts)
            }
        }
    }

    // MARK: - AX Helpers

    private func axAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success ? value : nil
    }
}
