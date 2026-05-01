//
//  NotchHoverController.swift
//  boringNotch
//
//  Heartbeat-based hover controller. Polls NSEvent.mouseLocation every 16ms
//  instead of trusting NSTrackingArea events (which fire spuriously during
//  SwiftUI layout shifts).
//

import SwiftUI

// MARK: - Hover State Machine

enum HoverState: Equatable {
    case outside
    case entering(since: Date)
    case inside
    case exiting(since: Date)
}

/// Controller for managing hover-based notch interactions via heartbeat polling.
@MainActor
@Observable class NotchHoverController {
    // MARK: - Dependencies

    private let settings: NotchViewModelSettings
    private let hoverZoneManager: any HoverZoneChecking

    // MARK: - Callbacks

    var onShouldOpen: (() -> Void)?
    var onShouldClose: (() -> Void)?

    /// Closure to check if close should be prevented (e.g. sharing active)
    var shouldPreventClose: () -> Bool = { false }

    /// Whether battery popover is active (prevents close)
    var isBatteryPopoverActive: Bool = false

    /// Closure to check if shelf is active (uses longer exit delay)
    var isShelfActive: () -> Bool = { false }

    // MARK: - State

    private(set) var state: HoverState = .outside

    var isHoveringNotch: Bool {
        switch state {
        case .outside: false
        case .entering, .inside, .exiting: true
        }
    }

    // MARK: - Timing

    private let enterDelay: TimeInterval = 0.050
    private let exitDelayNormal: TimeInterval = 0.500
    private var exitDelayShelf: TimeInterval { settings.shelfHoverDelay }

    private var activeExitDelay: TimeInterval {
        isShelfActive() ? exitDelayShelf : exitDelayNormal
    }

    // MARK: - Heartbeat

    private var heartbeat: Task<Void, Never>?

    // MARK: - Initialization

    init(
        settings: NotchViewModelSettings,
        displaySettings: any DisplaySettings,
        hoverZoneManager: (any HoverZoneChecking)? = nil
    ) {
        self.settings = settings
        self.hoverZoneManager = hoverZoneManager ?? HoverZoneManager(displaySettings: displaySettings)
    }

    // MARK: - Hover Zone

    func updateHoverZone(screenUUID: String?) {
        hoverZoneManager.updateHoverZone(screenUUID: screenUUID)
    }

    func isMouseInHoverZone() -> Bool {
        hoverZoneManager.isMouseInHoverZone()
    }

    func setNotchOpen(_ open: Bool) {
        hoverZoneManager.isNotchOpen = open
    }

    // MARK: - Heartbeat Control

    func startHeartbeat() {
        guard heartbeat == nil else { return }
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(32))
            }
        }
    }

    func stopHeartbeat() {
        heartbeat?.cancel()
        heartbeat = nil
        state = .outside
    }

    // MARK: - Core Tick

    func tick(now: Date = Date()) {
        let isInside = hoverZoneManager.isMouseInHoverZone()

        switch state {
        case .outside:
            if isInside {
                state = .entering(since: now)
            }

        case .entering(let since):
            if !isInside {
                state = .outside
            } else if now.timeIntervalSince(since) >= enterDelay {
                state = .inside
                onShouldOpen?()
            }

        case .inside:
            if !isInside {
                let shouldPrevent = isBatteryPopoverActive || shouldPreventClose()
                if shouldPrevent {
                    // Stay inside — close is blocked
                } else {
                    state = .exiting(since: now)
                }
            }

        case .exiting(let since):
            if isInside {
                state = .inside
            } else if now.timeIntervalSince(since) >= activeExitDelay {
                state = .outside
                onShouldClose?()
            }
        }
    }

    // MARK: - Event Hints

    /// Called by TrackingAreaView for low-latency response.
    /// Triggers an immediate tick and ensures the heartbeat is running.
    func handleHoverHint(_ signal: HoverSignal) {
        tick()
        if case .entering = state {
            startHeartbeat()
        }
    }

    // MARK: - Legacy API

    /// Cancel pending close (transitions exiting → inside)
    func cancelPendingClose() {
        if case .exiting = state {
            state = .inside
        }
    }

    /// Cancel pending open (transitions entering → outside)
    func cancelPendingOpen() {
        if case .entering = state {
            state = .outside
        }
    }
}
