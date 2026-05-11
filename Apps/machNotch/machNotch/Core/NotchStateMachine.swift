//
//  NotchStateMachine.swift
//  machNotch
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

// MARK: - State Machine

/// Centralizes state determination logic.
/// This class extracts the complex if-else chains from ContentView into a testable component.
struct NotchStateInput: Equatable {
    var isHelloAnimationRunning: Bool
    var notchState: NotchState
    var currentView: NotchViews
    var sneakPeek: SneakPeekState
    var expandingView: ExpandedItem
    var activePluginId: String?
    var isPlayerIdle: Bool
    var isPlaying: Bool
    var hideOnClosed: Bool
    var showInlineHUD: Bool
    var showNotHumanFace: Bool
    var sneakPeekStyle: SneakPeekStyle
    
    static func == (lhs: NotchStateInput, rhs: NotchStateInput) -> Bool {
        lhs.isHelloAnimationRunning == rhs.isHelloAnimationRunning &&
        lhs.notchState == rhs.notchState &&
        lhs.currentView == rhs.currentView &&
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

@MainActor
@Observable
class NotchStateMachine {
    private(set) var displayState: NotchDisplayState = .closed(content: .idle)

    /// Dependencies
    private weak var viewModel: NotchViewModel?
    private weak var coordinator: (any ViewCoordinating)?
    private weak var pluginManager: PluginManager?
    private let settings: NotchSettings
    
    @ObservationIgnored nonisolated(unsafe) private var observationTask: Task<Void, Never>?

    /// Production initializer
    init(
        viewModel: NotchViewModel,
        coordinator: any ViewCoordinating,
        pluginManager: PluginManager,
        settings: NotchSettings
    ) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        self.pluginManager = pluginManager
        self.settings = settings
        
        startObserving()
    }
    
    /// Testable initializer with injected settings
    init(settings: NotchSettings) {
        self.settings = settings
        self.viewModel = nil
        self.coordinator = nil
        self.pluginManager = nil
    }
    
    deinit {
        observationTask?.cancel()
    }

    /// Manually transition to a state (for testing computed properties like chinWidth)
    func transition(to state: NotchDisplayState) {
        displayState = state
    }
    
    private func startObserving() {
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                withObservationTracking {
                    self.update()
                } onChange: {
                    Task { @MainActor [weak self] in
                        self?.startObserving()
                    }
                }
                
                try? await Task.sleep(for: .seconds(86400))
            }
        }
    }

    /// Update the display state and publish changes
    func update() {
        let newState = computeDisplayState()
        if displayState != newState {
            displayState = newState
        }
        
        // Sync plugin preferred height for notch sizing
        if let activePluginId = pluginManager?.highestPriorityClosedNotchPlugin(),
           let plugin = pluginManager?.plugin(id: activePluginId),
           let preferredHeight = plugin.displayRequest?.preferredHeight {
            viewModel?.pluginPreferredHeight = preferredHeight
        } else {
            viewModel?.pluginPreferredHeight = nil
        }
    }


    func getCurrentInput(forcingClosed: Bool = false) -> NotchStateInput {
        return NotchStateInput(
            isHelloAnimationRunning: coordinator?.helloAnimationRunning ?? false,
            notchState: forcingClosed ? .closed : (viewModel?.notchState ?? .closed),
            currentView: viewModel?.currentView ?? .home,
            sneakPeek: coordinator?.sneakPeek ?? SneakPeekState(show: false, type: .music, value: 0, icon: ""),
            expandingView: coordinator?.expandingView ?? ExpandedItem(show: false, type: .battery, value: 0),
            activePluginId: pluginManager?.highestPriorityClosedNotchPlugin(),
            isPlayerIdle: pluginManager?.services.music.isPlayerIdle ?? true,
            isPlaying: pluginManager?.services.music.playbackState.isPlaying ?? false,
            hideOnClosed: viewModel?.hideOnClosed ?? false,
            showInlineHUD: settings.inlineHUD,
            showNotHumanFace: settings.showNotHumanFace,
            sneakPeekStyle: settings.sneakPeekStyles
        )
    }

    /// Compute the display state based on current inputs.
    func computeDisplayState(from input: NotchStateInput? = nil) -> NotchDisplayState {
        let input = input ?? getCurrentInput()
        
        // Priority 1: Hello animation
        if input.isHelloAnimationRunning {
            return .helloAnimation
        }

        // Priority 2: Open state
        if input.notchState == .open {
            return .open(view: input.currentView)
        }

        // From here, we're in closed state

        // Priority 3: Inline HUD
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

        // Priority 4: Standard sneak peek
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

        // Priority 5: Music sneak peek
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

        // Priority 5.5: Battery Expanding View
        if input.expandingView.show && input.expandingView.type == .battery && !input.hideOnClosed {
            return .closed(content: .plugin(PluginID.battery))
        }

        // Priority 6: Active Plugin Content
        if let pluginId = input.activePluginId,
           !input.hideOnClosed,
           !input.expandingView.show || input.expandingView.type == .music {
            return .closed(content: .plugin(pluginId))
        }

        // Priority 7: Face animation
        if !input.expandingView.show &&
           !input.isPlaying &&
           input.isPlayerIdle &&
           input.showNotHumanFace &&
           !input.hideOnClosed {
            return .closed(content: .face)
        }

        return .closed(content: .idle)
    }

    /// Determines what would be shown if the notch were forced to its closed state.
    var hypotheticalClosedState: NotchDisplayState {
        return computeDisplayState(from: getCurrentInput(forcingClosed: true))
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
