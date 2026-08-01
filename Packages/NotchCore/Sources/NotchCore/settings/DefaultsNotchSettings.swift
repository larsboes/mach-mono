//
//  DefaultsNotchSettings.swift
//  NotchCore
//
//  Production implementation of NotchSettings wrapping Defaults (UserDefaults).
//  Uses @Observable to support SwiftUI bindings via @Bindable.
//  Uses @Setting macro to generate Keys and accessors.
//

import Defaults
import Foundation
import NotchSettingsMacro
import Observation
import SwiftUI

@MainActor
@Observable
public final class DefaultsNotchSettings: NotchSettings {
    public static let shared = DefaultsNotchSettings()

    public init() {}

    public static var defaultMediaController: MediaControllerType {
        MediaControllerType.defaultController(
            isNowPlayingDeprecated: Defaults[Defaults.Key<Bool>("isNowPlayingDeprecated", default: false)])
    }

    // MARK: - Bluetooth

    @Setting<[BluetoothDeviceIconMapping]>(key: "bluetoothDeviceIconMappings", default: [])
    public var bluetoothDeviceIconMappings: [BluetoothDeviceIconMapping] {
        get { Defaults[Self.bluetoothDeviceIconMappingsKey] }
        set { Defaults[Self.bluetoothDeviceIconMappingsKey] = newValue }
    }

    @Setting<Bool>(key: "enableBluetoothSneakPeek", default: false)
    public var enableBluetoothSneakPeek: Bool {
        get { Defaults[Self.enableBluetoothSneakPeekKey] }
        set { Defaults[Self.enableBluetoothSneakPeekKey] = newValue }
    }

    @Setting<SneakPeekStyle>(key: "bluetoothSneakPeekStyle", default: .standard)
    public var bluetoothSneakPeekStyle: SneakPeekStyle {
        get { Defaults[Self.bluetoothSneakPeekStyleKey] }
        set { Defaults[Self.bluetoothSneakPeekStyleKey] = newValue }
    }

    // MARK: - General & Display

    @Setting<Bool>(key: "menubarIcon", default: true)
    public var menubarIcon: Bool {
        get { Defaults[Self.menubarIconKey] }
        set { Defaults[Self.menubarIconKey] = newValue }
    }

    @Setting<Bool>(key: "showOnAllDisplays", default: false)
    public var showOnAllDisplays: Bool {
        get { Defaults[Self.showOnAllDisplaysKey] }
        set { Defaults[Self.showOnAllDisplaysKey] = newValue }
    }

    @Setting<Bool>(key: "automaticallySwitchDisplay", default: true)
    public var automaticallySwitchDisplay: Bool {
        get { Defaults[Self.automaticallySwitchDisplayKey] }
        set { Defaults[Self.automaticallySwitchDisplayKey] = newValue }
    }

    @Setting<String?>(key: "preferred_screen_uuid", default: nil)
    public var preferredScreenUUID: String? {
        get { Defaults[Self.preferredScreenUUIDKey] }
        set { Defaults[Self.preferredScreenUUIDKey] = newValue }
    }

    @Setting<String>(key: "releaseName", default: "Flying Rabbit")
    public var releaseName: String {
        get { Defaults[Self.releaseNameKey] }
        set { Defaults[Self.releaseNameKey] = newValue }
    }

    @Setting<Bool>(key: "firstLaunch", default: true)
    public var firstLaunch: Bool {
        get { Defaults[Self.firstLaunchKey] }
        set { Defaults[Self.firstLaunchKey] = newValue }
    }

    @Setting<Bool>(key: "showWhatsNew", default: true)
    public var showWhatsNew: Bool {
        get { Defaults[Self.showWhatsNewKey] }
        set { Defaults[Self.showWhatsNewKey] = newValue }
    }

    // key differs from property name ("enableAI" vs "isAIEnabled")
    @Setting<Bool>(key: "enableAI", default: true)
    public var isAIEnabled: Bool {
        get { Defaults[Self.isAIEnabledKey] }
        set { Defaults[Self.isAIEnabledKey] = newValue }
    }

    @Setting<Bool>(key: "currentMicStatus", default: true)
    public var currentMicStatus: Bool {
        get { Defaults[Self.currentMicStatusKey] }
        set { Defaults[Self.currentMicStatusKey] = newValue }
    }

    // MARK: - Interaction

    @Setting<TimeInterval>(key: "minimumHoverDuration", default: 0.3)
    public var minimumHoverDuration: TimeInterval {
        get { Defaults[Self.minimumHoverDurationKey] }
        set { Defaults[Self.minimumHoverDurationKey] = newValue }
    }

    @Setting<Bool>(key: "enableHaptics", default: true)
    public var enableHaptics: Bool {
        get { Defaults[Self.enableHapticsKey] }
        set { Defaults[Self.enableHapticsKey] = newValue }
    }

    @Setting<Bool>(key: "openNotchOnHover", default: true)
    public var openNotchOnHover: Bool {
        get { Defaults[Self.openNotchOnHoverKey] }
        set { Defaults[Self.openNotchOnHoverKey] = newValue }
    }

    @Setting<Bool>(key: "extendHoverArea", default: false)
    public var extendHoverArea: Bool {
        get { Defaults[Self.extendHoverAreaKey] }
        set { Defaults[Self.extendHoverAreaKey] = newValue }
    }

    @Setting<Bool>(key: "enableGestures", default: true)
    public var enableGestures: Bool {
        get { Defaults[Self.enableGesturesKey] }
        set { Defaults[Self.enableGesturesKey] = newValue }
    }

    @Setting<Bool>(key: "closeGestureEnabled", default: true)
    public var closeGestureEnabled: Bool {
        get { Defaults[Self.closeGestureEnabledKey] }
        set { Defaults[Self.closeGestureEnabledKey] = newValue }
    }

    @Setting<CGFloat>(key: "gestureSensitivity", default: 200.0)
    public var gestureSensitivity: CGFloat {
        get { Defaults[Self.gestureSensitivityKey] }
        set { Defaults[Self.gestureSensitivityKey] = newValue }
    }

    @Setting<OptionKeyAction>(key: "optionKeyAction", default: OptionKeyAction.openSettings)
    public var optionKeyAction: OptionKeyAction {
        get { Defaults[Self.optionKeyActionKey] }
        set { Defaults[Self.optionKeyActionKey] = newValue }
    }

    // MARK: - Notch Sizing

    @Setting<Double>(key: "inactiveNotchHeight", default: 32)
    public var inactiveNotchHeight: Double {
        get { Defaults[Self.inactiveNotchHeightKey] }
        set { Defaults[Self.inactiveNotchHeightKey] = newValue }
    }

    @Setting<Bool>(key: "useInactiveNotchHeight", default: false)
    public var useInactiveNotchHeight: Bool {
        get { Defaults[Self.useInactiveNotchHeightKey] }
        set { Defaults[Self.useInactiveNotchHeightKey] = newValue }
    }

    @Setting<WindowHeightMode>(key: "notchHeightMode", default: WindowHeightMode.matchRealNotchSize)
    public var notchHeightMode: WindowHeightMode {
        get { Defaults[Self.notchHeightModeKey] }
        set { Defaults[Self.notchHeightModeKey] = newValue }
    }

    @Setting<WindowHeightMode>(key: "nonNotchHeightMode", default: WindowHeightMode.matchMenuBar)
    public var nonNotchHeightMode: WindowHeightMode {
        get { Defaults[Self.nonNotchHeightModeKey] }
        set { Defaults[Self.nonNotchHeightModeKey] = newValue }
    }

    @Setting<Double>(key: "nonNotchHeight", default: 32)
    public var nonNotchHeight: Double {
        get { Defaults[Self.nonNotchHeightKey] }
        set { Defaults[Self.nonNotchHeightKey] = newValue }
    }

    @Setting<Double>(key: "notchHeight", default: 32)
    public var notchHeight: Double {
        get { Defaults[Self.notchHeightKey] }
        set { Defaults[Self.notchHeightKey] = newValue }
    }

    @Setting<Bool>(key: "showOnLockScreen", default: false)
    public var showOnLockScreen: Bool {
        get { Defaults[Self.showOnLockScreenKey] }
        set { Defaults[Self.showOnLockScreenKey] = newValue }
    }

    @Setting<Bool>(key: "hideFromScreenRecording", default: false)
    public var hideFromScreenRecording: Bool {
        get { Defaults[Self.hideFromScreenRecordingKey] }
        set { Defaults[Self.hideFromScreenRecordingKey] = newValue }
    }

    @Setting<Bool>(key: "alwaysShowTabs", default: true)
    public var alwaysShowTabs: Bool {
        get { Defaults[Self.alwaysShowTabsKey] }
        set { Defaults[Self.alwaysShowTabsKey] = newValue }
    }

    @Setting<Bool>(key: "openLastTabByDefault", default: false)
    public var openLastTabByDefault: Bool {
        get { Defaults[Self.openLastTabByDefaultKey] }
        set { Defaults[Self.openLastTabByDefaultKey] = newValue }
    }

    @Setting<HideNotchOption>(key: "hideNotchOption", default: .nowPlayingOnly)
    public var hideNotchOption: HideNotchOption {
        get { Defaults[Self.hideNotchOptionKey] }
        set { Defaults[Self.hideNotchOptionKey] = newValue }
    }

    @Setting<Bool>(key: "hideTitleBar", default: true)
    public var hideTitleBar: Bool {
        get { Defaults[Self.hideTitleBarKey] }
        set { Defaults[Self.hideTitleBarKey] = newValue }
    }

    @Setting<Bool>(key: "hideNonNotchedFromMissionControl", default: true)
    public var hideNonNotchedFromMissionControl: Bool {
        get { Defaults[Self.hideNonNotchedFromMissionControlKey] }
        set { Defaults[Self.hideNonNotchedFromMissionControlKey] = newValue }
    }

    // MARK: - Plugin Visibility Toggles

    @Setting<Bool>(key: "showCalendar", default: true)
    public var showCalendar: Bool {
        get { Defaults[Self.showCalendarKey] }
        set { Defaults[Self.showCalendarKey] = newValue }
    }

    @Setting<Bool>(key: "showWeather", default: true)
    public var showWeather: Bool {
        get { Defaults[Self.showWeatherKey] }
        set { Defaults[Self.showWeatherKey] = newValue }
    }

    @Setting<Bool>(key: "showHabitTracker", default: true)
    public var showHabitTracker: Bool {
        get { Defaults[Self.showHabitTrackerKey] }
        set { Defaults[Self.showHabitTrackerKey] = newValue }
    }

    @Setting<Bool>(key: "showPomodoro", default: true)
    public var showPomodoro: Bool {
        get { Defaults[Self.showPomodoroKey] }
        set { Defaults[Self.showPomodoroKey] = newValue }
    }

    @Setting<Bool>(key: "showTeleprompter", default: true)
    public var showTeleprompter: Bool {
        get { Defaults[Self.showTeleprompterKey] }
        set { Defaults[Self.showTeleprompterKey] = newValue }
    }

    // MARK: - One-Time Migrations

    @Setting<Bool>(key: "isNowPlayingDeprecated", default: false)
    public var isNowPlayingDeprecated: Bool {
        get { Defaults[Self.isNowPlayingDeprecatedKey] }
        set { Defaults[Self.isNowPlayingDeprecatedKey] = newValue }
    }

    @Setting<Bool>(key: "didClearLegacyURLCache_v1", default: false)
    public var didClearLegacyURLCacheV1: Bool {
        get { Defaults[Self.didClearLegacyURLCacheV1Key] }
        set { Defaults[Self.didClearLegacyURLCacheV1Key] = newValue }
    }

    /// Returns `true` if the legacy URL cache still needs to be cleared, and marks it as done.
    public func consumeLegacyCacheCleanupFlag() -> Bool {
        if !Defaults[Self.didClearLegacyURLCacheV1Key] {
            Defaults[Self.didClearLegacyURLCacheV1Key] = true
            return true
        }
        return false
    }
}
