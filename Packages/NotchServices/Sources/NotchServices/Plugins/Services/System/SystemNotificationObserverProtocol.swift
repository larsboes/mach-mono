//
//  SystemNotificationObserverProtocol.swift
//  machNotch
//
//  Protocol for observing macOS system notifications from other apps.
//

import Foundation

@MainActor
public protocol SystemNotificationObserverProtocol {
    var isObserving: Bool { get }

    func startObserving()
    func stopObserving()
}
