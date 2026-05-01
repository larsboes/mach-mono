//
//  NotchPhase.swift
//  boringNotch
//
//  Represents the UI phase of the notch with explicit transition states.
//  Using phases instead of binary open/closed enables proper animation coordination.
//

import Foundation

/// The phase of the notch UI, including transition states.
/// This replaces the binary NotchState enum with explicit opening/closing phases
/// for smoother animations and proper click handling coordination.
public enum NotchPhase: Equatable, Sendable {
    /// Notch is fully closed (minimal size)
    case closed

    /// Notch is animating from closed to open
    case opening

    /// Notch is fully open (expanded size, interactive)
    case open

    /// Notch is animating from open to closed
    case closing

    // MARK: - Computed Properties

    /// Whether the notch should be rendered at open size
    var isVisible: Bool {
        self != .closed
    }

    /// Whether the notch is fully open and ready for interaction
    var isInteractive: Bool {
        self == .open
    }

    /// Whether clicks should be accepted (during open or opening)
    var shouldAcceptClicks: Bool {
        self == .open || self == .opening
    }

    /// Whether the notch is in a transition state
    var isTransitioning: Bool {
        self == .opening || self == .closing
    }
}
