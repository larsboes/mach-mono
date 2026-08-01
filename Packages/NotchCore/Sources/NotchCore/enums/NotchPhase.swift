//
//  NotchPhase.swift
//  NotchCore
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
    public var isVisible: Bool {
        self != .closed
    }

    /// Whether the notch is fully open and ready for interaction
    public var isInteractive: Bool {
        self == .open
    }

    /// Whether clicks should be accepted (during open or opening)
    public var shouldAcceptClicks: Bool {
        self == .open || self == .opening
    }

    /// Whether the notch is in a transition state
    public var isTransitioning: Bool {
        self == .opening || self == .closing
    }
}
