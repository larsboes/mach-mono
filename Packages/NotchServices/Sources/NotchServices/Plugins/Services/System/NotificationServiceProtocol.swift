//
//  NotificationServiceProtocol.swift
//  machNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation
import SwiftUI
import UserNotifications

@MainActor
public protocol NotificationServiceProtocol: Observable {
    var notifications: [NotchNotification] { get }
    var authorizationStatus: UNAuthorizationStatus { get }

    func requestAuthorization()
    func addNotification(_ notification: NotchNotification)
    func markAllAsRead()
    func clearAll()
    func removeNotification(_ notification: NotchNotification)
    func markAsRead(_ notification: NotchNotification)
    func refreshAuthorizationStatus()
}
