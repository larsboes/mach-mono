//
//  SystemNotificationObserverProtocol.swift
//  boringNotch
//
//  Protocol for observing macOS system notifications from other apps.
//

import Foundation

@MainActor
protocol SystemNotificationObserverProtocol {
    var isObserving: Bool { get }

    func startObserving()
    func stopObserving()
}
