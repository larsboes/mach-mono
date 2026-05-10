//
//  ViewCoordinating.swift
//  machNotch
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
/// NotchViewCoordinator conforms to this. Services and coordinators depend
/// on this protocol, never the concrete type.
@MainActor
protocol ViewCoordinating: AnyObject, NotchAnimationStateProviding {
    // MARK: - State (read-write overrides from NotchAnimationStateProviding)
    var helloAnimationRunning: Bool { get set }
    var sneakPeek: SneakPeekState { get set }
    var expandingView: ExpandedItem { get set }

    // NOTE: currentView has moved to NotchViewModel (per-screen state for multi-display).
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
