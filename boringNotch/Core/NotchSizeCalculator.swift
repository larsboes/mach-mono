//
//  NotchSizeCalculator.swift
//  boringNotch
//
//  Single source of truth for all closed-notch sizing.
//  Receives stable/debounced inputs — never reads services directly.
//

import SwiftUI

// MARK: - Input

/// All inputs needed to compute closed notch geometry.
/// Constructed by BoringViewModel from debounced/stable state.
struct ClosedNotchInput {
    let screenUUID: String?
    let hideOnClosed: Bool
    let sneakPeekActive: Bool
    let expandingViewActive: Bool
    let expandingViewType: SneakContentType?
    let pluginPreferredHeight: CGFloat?
    let closedEarsActive: Bool
    let showPowerStatusNotifications: Bool
    // Music state (passed through, not read from service)
    let isMusicPlaying: Bool
    let isPlayerIdle: Bool
    let showNotHumanFace: Bool
    let phase: NotchPhase
}

// MARK: - Calculator

/// Pure sizing calculator — no service dependencies, no reactive reads.
@MainActor
@Observable class NotchSizeCalculator {
    // MARK: - Dependencies

    private let settings: NotchViewModelSettings
    private let displaySettings: any DisplaySettings

    // MARK: - Stored Sizes (updated on screen change)

    var notchSize: CGSize = .zero
    var closedNotchSize: CGSize = .zero
    var inactiveNotchSize: CGSize = .zero

    // MARK: - Init

    init(settings: NotchViewModelSettings, displaySettings: any DisplaySettings) {
        self.settings = settings
        self.displaySettings = displaySettings

        let initial = getClosedNotchSize(settings: displaySettings)
        self.notchSize = initial
        self.closedNotchSize = initial
        self.inactiveNotchSize = getInactiveNotchSize(settings: displaySettings)
    }

    // MARK: - Screen Change

    func updateNotchSize(
        screenUUID: String?,
        currentState: NotchState
    ) -> (closedSize: CGSize, inactiveSize: CGSize, shouldUpdateNotchSize: Bool) {
        let newClosed = getClosedNotchSize(settings: displaySettings, screenUUID: screenUUID)
        let newInactive = getInactiveNotchSize(settings: displaySettings, screenUUID: screenUUID)

        self.closedNotchSize = newClosed
        self.inactiveNotchSize = newInactive

        return (newClosed, newInactive, currentState == .closed)
    }

    // MARK: - Effective Sizing

    /// Full closed notch size including ears and battery expansion.
    func effectiveClosedNotchSize(input: ClosedNotchInput) -> CGSize {
        let height = effectiveClosedNotchHeight(input: input)
        let inactiveHeight = max(10, inactiveNotchSize.height)
        let hasLiveActivity = height > inactiveHeight + 2 || input.pluginPreferredHeight != nil

        // When ears are active, always use the live-activity base size for width consistency.
        // Prevents narrow-base + wide-ears mismatch during debounce gaps where
        // closedEarsActive=true but hasLiveActivity=false (track transitions).
        let effectiveHasLive = hasLiveActivity || input.closedEarsActive

        let baseSize = getClosedNotchSize(
            settings: displaySettings, screenUUID: input.screenUUID, hasLiveActivity: effectiveHasLive
        )

        var size = CGSize(width: baseSize.width, height: height)

        if input.expandingViewType == .battery && input.expandingViewActive && input.showPowerStatusNotifications {
            size.width = 640
        } else if input.closedEarsActive && input.phase == .closed {
            size.width += (2 * max(0, baseSize.height - 12) + 20)
        }

        return size
    }

    /// Closed notch height based on live activity state.
    func effectiveClosedNotchHeight(input: ClosedNotchInput) -> CGFloat {
        let screen = input.screenUUID.flatMap { NSScreen.screen(withUUID: $0) }
        let isNoNotchFullscreen = input.hideOnClosed
            && (screen?.safeAreaInsets.top ?? 0 <= 0 || screen == nil)

        if isNoNotchFullscreen { return 0 }

        if let preferred = input.pluginPreferredHeight { return preferred }

        let isFaceActive = !input.isMusicPlaying && input.isPlayerIdle && input.showNotHumanFace

        let hasActiveLiveActivity = input.isMusicPlaying
            || input.sneakPeekActive
            || (input.expandingViewActive && input.expandingViewType == .battery)
            || isFaceActive

        if hasActiveLiveActivity {
            return getClosedNotchSize(settings: displaySettings, screenUUID: input.screenUUID, hasLiveActivity: true).height
        } else {
            return inactiveNotchSize.height
        }
    }

    /// Menu bar offset compensation.
    func chinHeight(input: ClosedNotchInput, notchState: NotchState) -> CGFloat {
        guard settings.hideTitleBar else { return 0 }

        guard let screen = input.screenUUID.flatMap({ NSScreen.screen(withUUID: $0) }) else { return 0 }

        if notchState == .open { return 0 }

        let effectiveHeight = effectiveClosedNotchHeight(input: input)
        if effectiveHeight == 0 { return 0 }

        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        return max(0, menuBarHeight - effectiveHeight)
    }
}
