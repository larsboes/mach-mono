//
//  NotificationsPlugin.swift
//  boringNotch
//
//  Built-in notifications plugin.
//  Wraps NotificationCenterManager to provide notification history.
//

import SwiftUI

@MainActor
@Observable
final class NotificationsPlugin: NotchPlugin {
    
    // MARK: - NotchPlugin
    
    let id = PluginID.notifications
    
    let metadata = PluginMetadata(
        name: "Notifications",
        description: "View and manage notifications",
        icon: "bell.badge.fill",
        version: "1.0.0",
        author: "boringNotch",
        category: .system
    )
    
    var isEnabled: Bool = true
    
    private(set) var state: PluginState = .inactive
    
    // MARK: - Dependencies

    var notificationService: (any NotificationServiceProtocol)?
    private var settings: PluginSettings?
    private var systemObserver: (any SystemNotificationObserverProtocol)?

    // MARK: - Initialization

    init() {}

    // MARK: - Lifecycle

    func activate(context: PluginContext) async throws {
        state = .activating

        self.notificationService = context.services.notifications
        self.settings = context.settings

        // Start observing macOS system notifications
        self.systemObserver = context.services.systemNotificationObserver
        self.systemObserver?.startObserving()

        state = .active
    }

    func deactivate() async {
        systemObserver?.stopObserving()
        systemObserver = nil
        notificationService = nil
        settings = nil
        state = .inactive
    }
    
    // MARK: - UI Slots
    
    @ViewBuilder
    func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            // NotificationsView will be updated to use Environment(\.pluginManager)
            NotificationsView()
        }
    }
    
    @ViewBuilder
    func settingsContent() -> some View {
        NotificationsSettingsView()
    }
}
