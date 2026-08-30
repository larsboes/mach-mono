//
//  FaceService.swift
//  machNotch
//
//  Created by Alexander on 2025-12-29.
//  Refactored by Agent on 2026-01-03.
//

import AppKit
import Foundation
import Observation

/// Tracks the pointer so the notch face can look at it, and notices when the
/// user goes idle.
///
/// Monitoring is reference counted and starts only when a view asks for it.
/// Nothing runs while no face is on screen.
@MainActor
@Observable
public final class FaceService: FaceServiceProtocol {
    // MARK: - Properties

    public var eyeOffset: CGSize = .zero
    public var isSleepy: Bool = false

    private var mouseMonitor: Any?
    private var idleTimer: Timer?
    private var lastPointerActivity = Date()
    private var observerCount = 0
    private let idleThreshold: TimeInterval = 10.0
    private var settings: any MediaSettings

    // MARK: - Initialization

    public init(settings: any MediaSettings) {
        self.settings = settings
    }

    // No `deinit` teardown: Swift 6 forbids reading main-actor state from a
    // nonisolated `deinit`, and `MainActor.assumeIsolated` would trap if the
    // last release ever landed off the main thread. Teardown is explicit
    // instead — `stopMonitoring()` balances `startMonitoring()`, and the only
    // long-lived owner is `ServiceContainer`, which lives as long as the app.

    // MARK: - Monitoring

    /// Reference counted: several faces can share one monitor.
    public func startMonitoring() {
        observerCount += 1
        guard observerCount == 1 else { return }

        lastPointerActivity = Date()
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMove(event.locationInWindow)
            return event
        }
        startIdleTimer()
    }

    public func stopMonitoring() {
        guard observerCount > 0 else { return }
        observerCount -= 1
        guard observerCount == 0 else { return }

        teardown()
        eyeOffset = .zero
        isSleepy = false
    }

    private func teardown() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        idleTimer?.invalidate()
        idleTimer = nil
    }

    // MARK: - Pointer

    private func handleMouseMove(_ location: NSPoint) {
        lastPointerActivity = Date()

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let screenFrame = screen.frame
        let dx = (location.x - screenFrame.midX) / (screenFrame.width / 2)
        let dy = (location.y - screenFrame.midY) / (screenFrame.height / 2)

        let offset = CGSize(width: dx * 2, height: -dy * 2)
        // Skip identical writes: this runs on every pointer event, and each
        // change invalidates every SwiftUI view reading `eyeOffset`.
        if offset != eyeOffset {
            eyeOffset = offset
        }

        if isSleepy {
            isSleepy = false
            if settings.selectedMood == .sleepy {
                settings.selectedMood = .neutral
            }
        }
    }

    // MARK: - Idle

    /// One repeating timer that compares timestamps.
    ///
    /// The previous version invalidated and allocated a `Timer` inside the
    /// pointer handler, so a single mouse sweep churned hundreds of them.
    private func startIdleTimer() {
        idleTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: idleThreshold, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateSleepiness()
            }
        }
        // Let the system coalesce this wake-up with others.
        timer.tolerance = idleThreshold / 5
        idleTimer = timer
    }

    private func updateSleepiness() {
        let idle = Date().timeIntervalSince(lastPointerActivity) >= idleThreshold
        if idle != isSleepy {
            isSleepy = idle
        }
    }
}
