//
//  ViewCoordinating.swift
//  NotchServices
//

import Foundation
import NotchCore

// MARK: - Animation State Protocol

/// Provides notch animation state to the state machine.
@MainActor public protocol NotchAnimationStateProviding: AnyObject {
    var helloAnimationRunning: Bool { get }
    var sneakPeek: SneakPeekState { get }
    var expandingView: ExpandedItem { get }
    var shelfService: (any ShelfServiceProtocol)? { get set }
}

// MARK: - View Coordinating Protocol

/// Contract for coordinator state used by non-view consumers.
@MainActor
public protocol ViewCoordinating: AnyObject, NotchAnimationStateProviding {
    // MARK: - State (read-write overrides from NotchAnimationStateProviding)
    var helloAnimationRunning: Bool { get set }
    var sneakPeek: SneakPeekState { get set }
    var expandingView: ExpandedItem { get set }

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
