//
//  NotchStateMachine.swift
//  boringNotch
//
//  Created as part of Phase 1 architectural refactoring.
//  Centralizes state determination logic from ContentView.
//

import Foundation
import Observation

// MARK: - Display State Types

/// Represents what the notch should display at any given moment.
/// This enum centralizes the branching logic currently scattered in ContentView.
enum NotchDisplayState: Equatable, Sendable {
    case closed(content: ClosedContent)
    case open(view: NotchViews)
    case helloAnimation
    case sneakPeek(type: SneakContentType, value: CGFloat, icon: String)
    case expanding(type: SneakContentType)

    /// Content displayed when the notch is closed
    enum ClosedContent: Equatable, Sendable {
        case idle
        case plugin(String) // Generic plugin content
        case face
        case inlineHUD(type: SneakContentType, value: CGFloat, icon: String)
        case sneakPeek(type: SneakContentType, value: CGFloat, icon: String)
    }
}

// MARK: - State Machine Input

/// All inputs needed to determine the current display state.
/// Extracted from various sources (coordinator, music manager, settings, etc.)
struct NotchStateInput: Equatable {
    // Core state
    var notchState: NotchState
    var currentView: NotchViews

    // Coordinator state
    var helloAnimationRunning: Bool
    var sneakPeek: SneakPeekState
    var expandingView: ExpandedItem
    
    // The ID of the plugin that should be shown in the closed notch (from PluginManager)
    var activePluginId: String?

    // Music state (Legacy - to be removed once MusicPlugin is fully autonomous)
    var isPlayerIdle: Bool
    var isPlaying: Bool

    // View model state
    var hideOnClosed: Bool

    // Settings (can be injected for testing)
    var showInlineHUD: Bool
    var showNotHumanFace: Bool
    var sneakPeekStyle: SneakPeekStyle

    static func == (lhs: NotchStateInput, rhs: NotchStateInput) -> Bool {
        lhs.notchState == rhs.notchState &&
        lhs.currentView == rhs.currentView &&
        lhs.helloAnimationRunning == rhs.helloAnimationRunning &&
        lhs.sneakPeek.show == rhs.sneakPeek.show &&
        lhs.sneakPeek.type == rhs.sneakPeek.type &&
        lhs.expandingView.show == rhs.expandingView.show &&
        lhs.expandingView.type == rhs.expandingView.type &&
        lhs.activePluginId == rhs.activePluginId &&
        lhs.isPlayerIdle == rhs.isPlayerIdle &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.hideOnClosed == rhs.hideOnClosed &&
        lhs.showInlineHUD == rhs.showInlineHUD &&
        lhs.showNotHumanFace == rhs.showNotHumanFace &&
        lhs.sneakPeekStyle == rhs.sneakPeekStyle
    }
}

// MARK: - State Machine

/// Centralizes state determination logic.
/// This class extracts the complex if-else chains from ContentView into a testable component.
@MainActor
@Observable
class NotchStateMachine {
    private(set) var displayState: NotchDisplayState = .closed(content: .idle)
    private(set) var lastInput: NotchStateInput?

    /// Settings provider - can be injected for testing
    private let settings: NotchSettings?

    /// Production initializer (singleton)
    private init() {
        self.settings = nil
    }

    /// Testable initializer with injected settings
    init(settings: NotchSettings) {
        self.settings = settings
    }

    /// Manually transition to a state (for testing computed properties like chinWidth)
    func transition(to state: NotchDisplayState) {
        displayState = state
    }

    /// Compute the display state based on current inputs.
    /// This mirrors the logic from ContentView.NotchLayout() but in a testable form.
    func computeDisplayState(from input: NotchStateInput) -> NotchDisplayState {
        // Store input for debugging
        lastInput = input

        // Priority 1: Hello animation
        if input.helloAnimationRunning {
            return .helloAnimation
        }

        // Priority 2: Open state
        if input.notchState == .open {
            return .open(view: input.currentView)
        }

        // From here, we're in closed state

        // Priority 3: Inline HUD (non-music, non-battery sneak peek with inline HUD enabled)
        if input.sneakPeek.show &&
           input.showInlineHUD &&
           input.sneakPeek.type != .music &&
           input.sneakPeek.type != .battery {
            return .closed(content: .inlineHUD(
                type: input.sneakPeek.type,
                value: input.sneakPeek.value,
                icon: input.sneakPeek.icon
            ))
        }

        // Priority 4: Active Plugin Content (replaces MusicLiveActivity and BatteryNotification)
        // Checks if a plugin requested display and explicit sneak peek isn't overriding it
        if let pluginId = input.activePluginId,
           !input.hideOnClosed,
           !input.expandingView.show || input.expandingView.type == .music || input.expandingView.type == .battery {
            return .closed(content: .plugin(pluginId))
        }

        // Priority 5: Face animation (when not playing and face enabled)
        // Legacy check relying on input.isPlayerIdle - eventually Face should be a plugin too
        if !input.expandingView.show &&
           !input.isPlaying &&
           input.isPlayerIdle &&
           input.showNotHumanFace &&
           !input.hideOnClosed {
            return .closed(content: .face)
        }

        // Priority 6: Standard sneak peek (non-inline HUD)
        if input.sneakPeek.show &&
           !input.showInlineHUD &&
           input.sneakPeek.type != .music &&
           input.sneakPeek.type != .battery {
            return .closed(content: .sneakPeek(
                type: input.sneakPeek.type,
                value: input.sneakPeek.value,
                icon: input.sneakPeek.icon
            ))
        }

        // Priority 7: Music sneak peek (standard style)
        if input.sneakPeek.show &&
           input.sneakPeek.type == .music &&
           !input.hideOnClosed &&
           input.sneakPeekStyle == .standard {
            return .closed(content: .sneakPeek(
                type: .music,
                value: input.sneakPeek.value,
                icon: input.sneakPeek.icon
            ))
        }

        // Default: idle
        return .closed(content: .idle)
    }

    /// Update the display state and publish changes
    func update(with input: NotchStateInput) {
        let newState = computeDisplayState(from: input)
        if displayState != newState {
            displayState = newState
        }
    }

    /// Determines what would be shown if the notch were forced to its closed state.
    /// This is used by NotchContentRouter to provide seamless cross-fades during transitions (no black gap).
    var hypotheticalClosedState: NotchDisplayState {
        guard let input = lastInput else { return .closed(content: .idle) }
        var closedInput = input
        closedInput.notchState = .closed
        return computeDisplayState(from: closedInput)
    }
}

// MARK: - Computed Properties (for ContentView compatibility)

extension NotchStateMachine {
    /// Compute the chin width based on display state.
    /// This extracts the computedChinWidth logic from ContentView.
    func computeChinWidth(
        baseWidth: CGFloat,
        displayClosedNotchHeight: CGFloat
    ) -> CGFloat {
        switch displayState {
        case .closed(let content):
            switch content {
            // Plugin content usually needs wider chin, similar to music/face
            // Future: Ask the plugin for its preferred width
            case .plugin, .face:
                return baseWidth + (2 * max(0, displayClosedNotchHeight - 12) + 20)
            default:
                return baseWidth
            }
        case .open, .helloAnimation, .sneakPeek, .expanding:
            return baseWidth
        }
    }

    /// Whether the notch should show sneak peek overlay
    var shouldShowSneakPeekOverlay: Bool {
        if case .closed(let content) = displayState {
            switch content {
            case .sneakPeek, .inlineHUD:
                return true
            default:
                return false
            }
        }
        return false
    }
}
