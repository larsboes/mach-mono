//
//  DefaultsNotchSettings+HUD.swift
//  boringNotch
//

import Foundation
import Defaults

@MainActor extension DefaultsNotchSettings {
    // MARK: - HUD Settings
    var currentMicStatus: Bool {
        get { Defaults[.currentMicStatus] }
        set { Defaults[.currentMicStatus] = newValue }
    }
    var showInlineHUD: Bool { Defaults[.inlineHUD] }
    var hudReplacement: Bool {
        get { Defaults[.hudReplacement] }
        set { Defaults[.hudReplacement] = newValue }
    }
    var showOpenNotchHUD: Bool {
        get { Defaults[.showOpenNotchHUD] }
        set { Defaults[.showOpenNotchHUD] = newValue }
    }
    var showOpenNotchHUDPercentage: Bool {
        get { Defaults[.showOpenNotchHUDPercentage] }
        set { Defaults[.showOpenNotchHUDPercentage] = newValue }
    }
    var showClosedNotchHUDPercentage: Bool {
        get { Defaults[.showClosedNotchHUDPercentage] }
        set { Defaults[.showClosedNotchHUDPercentage] = newValue }
    }
    var showBatteryPercentage: Bool {
        get { Defaults[.showBatteryPercentage] }
        set { Defaults[.showBatteryPercentage] = newValue }
    }
    var inlineHUD: Bool {
        get { Defaults[.inlineHUD] }
        set { Defaults[.inlineHUD] = newValue }
    }
    var optionKeyAction: OptionKeyAction {
        get { Defaults[.optionKeyAction] }
        set { Defaults[.optionKeyAction] = newValue }
    }
    var enableGradient: Bool {
        get { Defaults[.enableGradient] }
        set { Defaults[.enableGradient] = newValue }
    }
    var systemEventIndicatorUseAccent: Bool {
        get { Defaults[.systemEventIndicatorUseAccent] }
        set { Defaults[.systemEventIndicatorUseAccent] = newValue }
    }
    var systemEventIndicatorShadow: Bool {
        get { Defaults[.systemEventIndicatorShadow] }
        set { Defaults[.systemEventIndicatorShadow] = newValue }
    }

    // MARK: - Battery Settings
    var showPowerStatusNotifications: Bool {
        get { Defaults[.showPowerStatusNotifications] }
        set { Defaults[.showPowerStatusNotifications] = newValue }
    }
    var showBatteryIndicator: Bool {
        get { Defaults[.showBatteryIndicator] }
        set { Defaults[.showBatteryIndicator] = newValue }
    }
    var showPowerStatusIcons: Bool {
        get { Defaults[.showPowerStatusIcons] }
        set { Defaults[.showPowerStatusIcons] = newValue }
    }
    var powerStatusNotificationSound: String {
        get { Defaults[.powerStatusNotificationSound] }
        set { Defaults[.powerStatusNotificationSound] = newValue }
    }
    var lowBatteryNotificationLevel: Int {
        get { Defaults[.lowBatteryNotificationLevel] }
        set { Defaults[.lowBatteryNotificationLevel] = newValue }
    }
    var lowBatteryNotificationSound: String {
        get { Defaults[.lowBatteryNotificationSound] }
        set { Defaults[.lowBatteryNotificationSound] = newValue }
    }
    var highBatteryNotificationLevel: Int {
        get { Defaults[.highBatteryNotificationLevel] }
        set { Defaults[.highBatteryNotificationLevel] = newValue }
    }
    var highBatteryNotificationSound: String {
        get { Defaults[.highBatteryNotificationSound] }
        set { Defaults[.highBatteryNotificationSound] = newValue }
    }

    // MARK: - Notification Settings
    var showShelfNotifications: Bool {
        get { Defaults[.showShelfNotifications] }
        set { Defaults[.showShelfNotifications] = newValue }
    }
    var showSystemNotifications: Bool {
        get { Defaults[.showSystemNotifications] }
        set { Defaults[.showSystemNotifications] = newValue }
    }
    var showInfoNotifications: Bool {
        get { Defaults[.showInfoNotifications] }
        set { Defaults[.showInfoNotifications] = newValue }
    }
    var notificationDeliveryStyle: NotificationDeliveryStyle {
        get { Defaults[.notificationDeliveryStyle] }
        set { Defaults[.notificationDeliveryStyle] = newValue }
    }
    var notificationSoundEnabled: Bool {
        get { Defaults[.notificationSoundEnabled] }
        set { Defaults[.notificationSoundEnabled] = newValue }
    }
    var respectDoNotDisturb: Bool {
        get { Defaults[.respectDoNotDisturb] }
        set { Defaults[.respectDoNotDisturb] = newValue }
    }
    var notificationRetentionDays: Int {
        get { Defaults[.notificationRetentionDays] }
        set { Defaults[.notificationRetentionDays] = newValue }
    }
    var storedNotifications: [NotchNotification] {
        get { Defaults[.storedNotifications] }
        set { Defaults[.storedNotifications] = newValue }
    }
}
