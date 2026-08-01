//
//  DefaultsNotchSettings+Battery.swift
//  NotchCore
//
//  Battery indicator, power status notifications, and HUD settings.
//

import Defaults
import NotchSettingsMacro
import SwiftUI

public extension DefaultsNotchSettings {

    // MARK: - Battery Indicator

    @Setting<Bool>(key: "showBatteryIndicator", default: true)
    var showBatteryIndicator: Bool {
        get { Defaults[Self.showBatteryIndicatorKey] }
        set { Defaults[Self.showBatteryIndicatorKey] = newValue }
    }

    @Setting<Bool>(key: "showBatteryPercentage", default: true)
    var showBatteryPercentage: Bool {
        get { Defaults[Self.showBatteryPercentageKey] }
        set { Defaults[Self.showBatteryPercentageKey] = newValue }
    }

    @Setting<Bool>(key: "showPowerStatusIcons", default: true)
    var showPowerStatusIcons: Bool {
        get { Defaults[Self.showPowerStatusIconsKey] }
        set { Defaults[Self.showPowerStatusIconsKey] = newValue }
    }

    // MARK: - Power Notifications

    @Setting<Bool>(key: "showPowerStatusNotifications", default: true)
    var showPowerStatusNotifications: Bool {
        get { Defaults[Self.showPowerStatusNotificationsKey] }
        set { Defaults[Self.showPowerStatusNotificationsKey] = newValue }
    }

    @Setting<String>(key: "powerStatusNotificationSound", default: "Disabled")
    var powerStatusNotificationSound: String {
        get { Defaults[Self.powerStatusNotificationSoundKey] }
        set { Defaults[Self.powerStatusNotificationSoundKey] = newValue }
    }

    @Setting<Int>(key: "lowBatteryNotificationLevel", default: 0)
    var lowBatteryNotificationLevel: Int {
        get { Defaults[Self.lowBatteryNotificationLevelKey] }
        set { Defaults[Self.lowBatteryNotificationLevelKey] = newValue }
    }

    @Setting<String>(key: "lowBatteryNotificationSound", default: "Disabled")
    var lowBatteryNotificationSound: String {
        get { Defaults[Self.lowBatteryNotificationSoundKey] }
        set { Defaults[Self.lowBatteryNotificationSoundKey] = newValue }
    }

    @Setting<Int>(key: "highBatteryNotificationLevel", default: 0)
    var highBatteryNotificationLevel: Int {
        get { Defaults[Self.highBatteryNotificationLevelKey] }
        set { Defaults[Self.highBatteryNotificationLevelKey] = newValue }
    }

    @Setting<String>(key: "highBatteryNotificationSound", default: "Disabled")
    var highBatteryNotificationSound: String {
        get { Defaults[Self.highBatteryNotificationSoundKey] }
        set { Defaults[Self.highBatteryNotificationSoundKey] = newValue }
    }

    // MARK: - HUD

    @Setting<Bool>(key: "hudReplacement", default: false)
    var hudReplacement: Bool {
        get { Defaults[Self.hudReplacementKey] }
        set { Defaults[Self.hudReplacementKey] = newValue }
    }

    @Setting<Bool>(key: "inlineHUD", default: false)
    var inlineHUD: Bool {
        get { Defaults[Self.inlineHUDKey] }
        set { Defaults[Self.inlineHUDKey] = newValue }
    }

    var showInlineHUD: Bool { inlineHUD }

    @Setting<Bool>(key: "enableGradient", default: false)
    var enableGradient: Bool {
        get { Defaults[Self.enableGradientKey] }
        set { Defaults[Self.enableGradientKey] = newValue }
    }

    @Setting<Bool>(key: "systemEventIndicatorShadow", default: false)
    var systemEventIndicatorShadow: Bool {
        get { Defaults[Self.systemEventIndicatorShadowKey] }
        set { Defaults[Self.systemEventIndicatorShadowKey] = newValue }
    }

    @Setting<Bool>(key: "systemEventIndicatorUseAccent", default: false)
    var systemEventIndicatorUseAccent: Bool {
        get { Defaults[Self.systemEventIndicatorUseAccentKey] }
        set { Defaults[Self.systemEventIndicatorUseAccentKey] = newValue }
    }

    @Setting<Bool>(key: "showOpenNotchHUD", default: true)
    var showOpenNotchHUD: Bool {
        get { Defaults[Self.showOpenNotchHUDKey] }
        set { Defaults[Self.showOpenNotchHUDKey] = newValue }
    }

    @Setting<Bool>(key: "showOpenNotchHUDPercentage", default: true)
    var showOpenNotchHUDPercentage: Bool {
        get { Defaults[Self.showOpenNotchHUDPercentageKey] }
        set { Defaults[Self.showOpenNotchHUDPercentageKey] = newValue }
    }

    @Setting<Bool>(key: "showClosedNotchHUDPercentage", default: false)
    var showClosedNotchHUDPercentage: Bool {
        get { Defaults[Self.showClosedNotchHUDPercentageKey] }
        set { Defaults[Self.showClosedNotchHUDPercentageKey] = newValue }
    }
}
