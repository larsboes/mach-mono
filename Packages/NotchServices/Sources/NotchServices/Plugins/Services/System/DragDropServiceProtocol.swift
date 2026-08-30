//
//  DragDropServiceProtocol.swift
//  machNotch
//
//  Created as part of Phase 3 architectural refactoring.
//

import CoreGraphics
import Foundation

/// Identifies one registered drag observer. Hold it to update the observer's
/// region or to remove it.
public struct DragDropObserverToken: Hashable, Sendable {
    fileprivate let id: UUID

    fileprivate init() {
        self.id = UUID()
    }
}

/// Watches drags across the system and reports when one crosses a caller's region.
///
/// Observers are a list, not a single slot. Every notch window registers its own
/// screen region, so a second display cannot overwrite the first one's callbacks.
///
/// The service installs its system-wide monitors when the first observer arrives
/// and removes them when the last one leaves. There is no separate start or stop
/// call, so it can never be left monitoring for nobody.
@MainActor
public protocol DragDropServiceProtocol: AnyObject {
    /// Number of registered observers. Zero means no monitors are installed.
    var observerCount: Int { get }

    @discardableResult
    func addObserver(
        region: CGRect,
        onEnter: (() -> Void)?,
        onExit: (() -> Void)?,
        onMove: ((CGPoint) -> Void)?
    ) -> DragDropObserverToken

    /// Moves an existing observer's region, for example when the notch resizes.
    func updateRegion(_ region: CGRect, for token: DragDropObserverToken)

    func removeObserver(_ token: DragDropObserverToken)
}

extension DragDropServiceProtocol {
    @discardableResult
    public func addObserver(region: CGRect, onEnter: @escaping () -> Void) -> DragDropObserverToken {
        addObserver(region: region, onEnter: onEnter, onExit: nil, onMove: nil)
    }

    /// True while at least one observer is registered.
    public var isMonitoring: Bool { observerCount > 0 }
}

extension DragDropObserverToken {
    /// Namespaced so only the service can mint tokens.
    public static func make() -> DragDropObserverToken { DragDropObserverToken() }
}
