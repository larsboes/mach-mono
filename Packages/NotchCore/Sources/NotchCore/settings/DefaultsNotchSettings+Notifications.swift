//
//  DefaultsNotchSettings+Notifications.swift
//  NotchCore
//
//  Notification delivery, download listeners, and system notification settings.
//

import Defaults
import NotchSettingsMacro

public extension DefaultsNotchSettings {

    // MARK: - Notification Delivery

    @Setting<Bool>(key: "showShelfNotifications", default: true)
    var showShelfNotifications: Bool {
        get { Defaults[Self.showShelfNotificationsKey] }
        set { Defaults[Self.showShelfNotificationsKey] = newValue }
    }

    @Setting<Bool>(key: "showSystemNotifications", default: true)
    var showSystemNotifications: Bool {
        get { Defaults[Self.showSystemNotificationsKey] }
        set { Defaults[Self.showSystemNotificationsKey] = newValue }
    }

    @Setting<Bool>(key: "showInfoNotifications", default: true)
    var showInfoNotifications: Bool {
        get { Defaults[Self.showInfoNotificationsKey] }
        set { Defaults[Self.showInfoNotificationsKey] = newValue }
    }

    @Setting<NotificationDeliveryStyle>(key: "notificationDeliveryStyle", default: .banner)
    var notificationDeliveryStyle: NotificationDeliveryStyle {
        get { Defaults[Self.notificationDeliveryStyleKey] }
        set { Defaults[Self.notificationDeliveryStyleKey] = newValue }
    }

    @Setting<Bool>(key: "notificationSoundEnabled", default: true)
    var notificationSoundEnabled: Bool {
        get { Defaults[Self.notificationSoundEnabledKey] }
        set { Defaults[Self.notificationSoundEnabledKey] = newValue }
    }

    @Setting<Bool>(key: "respectDoNotDisturb", default: true)
    var respectDoNotDisturb: Bool {
        get { Defaults[Self.respectDoNotDisturbKey] }
        set { Defaults[Self.respectDoNotDisturbKey] = newValue }
    }

    @Setting<Int>(key: "notificationRetentionDays", default: 7)
    var notificationRetentionDays: Int {
        get { Defaults[Self.notificationRetentionDaysKey] }
        set { Defaults[Self.notificationRetentionDaysKey] = newValue }
    }

    @Setting<[NotchNotification]>(key: "storedNotifications", default: [])
    var storedNotifications: [NotchNotification] {
        get { Defaults[Self.storedNotificationsKey] }
        set { Defaults[Self.storedNotificationsKey] = newValue }
    }

    // MARK: - Downloads

    @Setting<Bool>(key: "enableDownloadListener", default: true)
    var enableDownloadListener: Bool {
        get { Defaults[Self.enableDownloadListenerKey] }
        set { Defaults[Self.enableDownloadListenerKey] = newValue }
    }

    @Setting<Bool>(key: "enableSafariDownloads", default: true)
    var enableSafariDownloads: Bool {
        get { Defaults[Self.enableSafariDownloadsKey] }
        set { Defaults[Self.enableSafariDownloadsKey] = newValue }
    }

    @Setting<DownloadIndicatorStyle>(key: "selectedDownloadIndicatorStyle", default: DownloadIndicatorStyle.progress)
    var selectedDownloadIndicatorStyle: DownloadIndicatorStyle {
        get { Defaults[Self.selectedDownloadIndicatorStyleKey] }
        set { Defaults[Self.selectedDownloadIndicatorStyleKey] = newValue }
    }

    @Setting<DownloadIconStyle>(key: "selectedDownloadIconStyle", default: DownloadIconStyle.onlyAppIcon)
    var selectedDownloadIconStyle: DownloadIconStyle {
        get { Defaults[Self.selectedDownloadIconStyleKey] }
        set { Defaults[Self.selectedDownloadIconStyleKey] = newValue }
    }
}
