//
//  PluginUIContext.swift
//  machNotch
//
//  Decoupled UI state context provided to plugins via the SwiftUI Environment.
//  Resolves DIP violations by preventing plugins from depending on the concrete NotchViewModel.
//

import SwiftUI

@MainActor
@Observable
public final class PluginUIContext {
    // Read-only UI state from the Notch system
    public internal(set) var notchState: NotchState = .closed
    public internal(set) var phase: NotchPhase = .closed
    public internal(set) var closedNotchSize: CGSize = .zero
    public internal(set) var notchSize: CGSize = .zero

    // Two-way bindings for plugin interactions
    public var isScrollableViewPresented: Bool = false
    public var dragDetectorTargeting: Bool = false
    public var dropZoneTargeting: Bool = false
    public var dropEvent: Bool = false
    public var isBatteryPopoverActive: Bool = false

    // Actions
    public var openAction: ((CGFloat) -> Void)?
    public var closeAction: ((Bool) -> Void)?
    public var cancelPendingOpenAction: (() -> Void)?

    public init() {}

    public func open(initialVelocity: CGFloat = 0) {
        openAction?(initialVelocity)
    }

    public func close(force: Bool = false) {
        closeAction?(force)
    }

    public func cancelPendingOpen() {
        cancelPendingOpenAction?()
    }
}
