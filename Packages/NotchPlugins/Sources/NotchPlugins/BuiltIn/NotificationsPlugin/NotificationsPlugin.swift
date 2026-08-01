//
//  NotificationsPlugin.swift
//  machNotch
//
//  Built-in notifications plugin.
//  Wraps NotificationCenterManager to provide notification history.
//

import SwiftUI

@MainActor
@Observable
public final class NotificationsPlugin: NotchPlugin {

    // MARK: - NotchPlugin

    public let id = PluginID.notifications

    public let metadata = PluginMetadata(
        name: "Notifications",
        description: "View and manage notifications",
        icon: "bell.badge.fill",
        version: "1.0.0",
        author: "machNotch",
        category: .system
    )

    public var isEnabled: Bool = true

    public private(set) var state: PluginState = .inactive

    // MARK: - Dependencies

    public var notificationService: (any NotificationServiceProtocol)?
    private var settings: PluginSettings?
    private var systemObserver: (any SystemNotificationObserverProtocol)?

    // MARK: - Initialization

    public init() {}

    // MARK: - Lifecycle

    public func activate(context: PluginContext) async throws {
        state = .activating

        self.notificationService = context.uiServices.notifications
        self.settings = context.settings

        // Start observing macOS system notifications
        self.systemObserver = context.uiServices.systemNotificationObserver
        self.systemObserver?.startObserving()

        state = .active
    }

    public func deactivate() async {
        systemObserver?.stopObserving()
        systemObserver = nil
        notificationService = nil
        settings = nil
        state = .inactive
    }

    // MARK: - UI Slots

    @ViewBuilder
    public func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            // NotificationsView will be updated to use Environment(\.pluginManager)
            NotificationsView()
        }
    }

    @ViewBuilder
    public func settingsContent() -> some View {
        NotificationsSettingsView()
    }
}
