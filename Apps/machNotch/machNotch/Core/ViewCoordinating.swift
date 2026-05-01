//
//  ViewCoordinating.swift
//  boringNotch
//
//  Application-layer protocol for coordinator state.
//  Views that need @Bindable use the concrete type; services use this protocol.
//

import Foundation

// MARK: - Animation State Protocol

/// Provides notch animation state to the state machine.
/// Defined here (application layer) because ShelfServiceProtocol imports AppKit.
@MainActor protocol NotchAnimationStateProviding: AnyObject {
    var helloAnimationRunning: Bool { get }
    var sneakPeek: SneakPeekState { get }
    var expandingView: ExpandedItem { get }
    var shelfService: (any ShelfServiceProtocol)? { get set }
}

// MARK: - View Coordinating Protocol

/// Contract for coordinator state used by non-view consumers.
/// BoringViewCoordinator conforms to this. Services and coordinators depend
/// on this protocol, never the concrete type.
@MainActor
protocol ViewCoordinating: AnyObject, NotchAnimationStateProviding {
    // MARK: - State (read-write overrides from NotchAnimationStateProviding)
    var helloAnimationRunning: Bool { get set }
    var sneakPeek: SneakPeekState { get set }
    var expandingView: ExpandedItem { get set }

    // NOTE: currentView has moved to BoringViewModel (per-screen state for multi-display).
    // The coordinator still owns shared state (sneakPeek, expandingView, helloAnimation).
    var isScrollableViewPresented: Bool { get }
    var selectedScreenUUID: String { get }
    var alwaysShowTabs: Bool { get set }
    var openLastTabByDefault: Bool { get set }
    var firstLaunch: Bool { get set }
    var preferredScreenUUID: String? { get set }

    // MARK: - Actions
    func toggleSneakPeek(status: Bool, type: SneakContentType, duration: TimeInterval, value: CGFloat, icon: String)
    func toggleExpandingView(status: Bool, type: SneakContentType, value: CGFloat, browser: BrowserType)
}

// MARK: - State Machine Input Factory

extension NotchStateMachine {
    /// Create input from current app state. Lives here because it depends on service protocols.
    static func createInput(
        notchState: NotchState,
        currentView: NotchViews,
        coordinator: any NotchAnimationStateProviding,
        musicService: any MusicServiceProtocol,
        pluginManager: PluginManager?,
        hideOnClosed: Bool,
        settings: NotchSettings
    ) -> NotchStateInput {
        NotchStateInput(
            notchState: notchState,
            currentView: currentView,
            helloAnimationRunning: coordinator.helloAnimationRunning,
            sneakPeek: coordinator.sneakPeek,
            expandingView: coordinator.expandingView,
            activePluginId: pluginManager?.highestPriorityClosedNotchPlugin(),
            isPlayerIdle: musicService.isPlayerIdle,
            isPlaying: musicService.playbackState.isPlaying,
            hideOnClosed: hideOnClosed,
            showInlineHUD: settings.inlineHUD,
            showNotHumanFace: settings.showNotHumanFace,
            sneakPeekStyle: settings.sneakPeekStyles
        )
    }
}
