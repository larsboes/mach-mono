//
//  DefaultsNotchSettings.swift
//  machNotch
//
//  Production implementation of NotchSettings wrapping Defaults (UserDefaults).
//  Uses @Observable to support SwiftUI bindings via @Bindable.
//  Uses @Setting macro to generate Keys and accessors.
//

import Foundation
import Defaults
import Observation
import NotchSettingsMacro
import SwiftUI

@MainActor
@Observable
final class DefaultsNotchSettings: NotchSettings {
    static let shared = DefaultsNotchSettings()

    static var defaultMediaController: MediaControllerType {
        MediaControllerType.defaultController(isNowPlayingDeprecated: Defaults[Defaults.Key<Bool>("isNowPlayingDeprecated", default: false)])
    }

    @Setting<[BluetoothDeviceIconMapping]>(key: "bluetoothDeviceIconMappings", default: [])
    var bluetoothDeviceIconMappings: [BluetoothDeviceIconMapping] {
        get { Defaults[Self.bluetoothDeviceIconMappingsKey] }
        set { Defaults[Self.bluetoothDeviceIconMappingsKey] = newValue }
    }

    @Setting<Bool>(key: "enableBluetoothSneakPeek", default: false)
    var enableBluetoothSneakPeek: Bool {
        get { Defaults[Self.enableBluetoothSneakPeekKey] }
        set { Defaults[Self.enableBluetoothSneakPeekKey] = newValue }
    }

    @Setting<SneakPeekStyle>(key: "bluetoothSneakPeekStyle", default: .standard)
    var bluetoothSneakPeekStyle: SneakPeekStyle {
        get { Defaults[Self.bluetoothSneakPeekStyleKey] }
        set { Defaults[Self.bluetoothSneakPeekStyleKey] = newValue }
    }

    @Setting<Bool>(key: "menubarIcon", default: true)
    var menubarIcon: Bool {
        get { Defaults[Self.menubarIconKey] }
        set { Defaults[Self.menubarIconKey] = newValue }
    }

    @Setting<Bool>(key: "showOnAllDisplays", default: false)
    var showOnAllDisplays: Bool {
        get { Defaults[Self.showOnAllDisplaysKey] }
        set { Defaults[Self.showOnAllDisplaysKey] = newValue }
    }

    @Setting<Bool>(key: "automaticallySwitchDisplay", default: true)
    var automaticallySwitchDisplay: Bool {
        get { Defaults[Self.automaticallySwitchDisplayKey] }
        set { Defaults[Self.automaticallySwitchDisplayKey] = newValue }
    }

    @Setting<String?>(key: "preferred_screen_uuid", default: nil)
    var preferredScreenUUID: String? {
        get { Defaults[Self.preferredScreenUUIDKey] }
        set { Defaults[Self.preferredScreenUUIDKey] = newValue }
    }

    @Setting<String>(key: "releaseName", default: "Flying Rabbit")
    var releaseName: String {
        get { Defaults[Self.releaseNameKey] }
        set { Defaults[Self.releaseNameKey] = newValue }
    }

    @Setting<Bool>(key: "firstLaunch", default: true)
    var firstLaunch: Bool {
        get { Defaults[Self.firstLaunchKey] }
        set { Defaults[Self.firstLaunchKey] = newValue }
    }

    @Setting<Bool>(key: "showWhatsNew", default: true)
    var showWhatsNew: Bool {
        get { Defaults[Self.showWhatsNewKey] }
        set { Defaults[Self.showWhatsNewKey] = newValue }
    }

    // key differs from property name ("enableAI" vs "isAIEnabled")
    @Setting<Bool>(key: "enableAI", default: true)
    var isAIEnabled: Bool {
        get { Defaults[Self.isAIEnabledKey] }
        set { Defaults[Self.isAIEnabledKey] = newValue }
    }

    @Setting<Bool>(key: "musicLiveActivityEnabled", default: true)
    var musicLiveActivityEnabled: Bool {
        get { Defaults[Self.musicLiveActivityEnabledKey] }
        set { Defaults[Self.musicLiveActivityEnabledKey] = newValue }
    }

    @Setting<Bool>(key: "currentMicStatus", default: true)
    var currentMicStatus: Bool {
        get { Defaults[Self.currentMicStatusKey] }
        set { Defaults[Self.currentMicStatusKey] = newValue }
    }

    @Setting<TimeInterval>(key: "minimumHoverDuration", default: 0.3)
    var minimumHoverDuration: TimeInterval {
        get { Defaults[Self.minimumHoverDurationKey] }
        set { Defaults[Self.minimumHoverDurationKey] = newValue }
    }

    @Setting<Bool>(key: "enableHaptics", default: true)
    var enableHaptics: Bool {
        get { Defaults[Self.enableHapticsKey] }
        set { Defaults[Self.enableHapticsKey] = newValue }
    }

    @Setting<Bool>(key: "openNotchOnHover", default: true)
    var openNotchOnHover: Bool {
        get { Defaults[Self.openNotchOnHoverKey] }
        set { Defaults[Self.openNotchOnHoverKey] = newValue }
    }

    @Setting<Bool>(key: "extendHoverArea", default: false)
    var extendHoverArea: Bool {
        get { Defaults[Self.extendHoverAreaKey] }
        set { Defaults[Self.extendHoverAreaKey] = newValue }
    }

    @Setting<Double>(key: "inactiveNotchHeight", default: 32)
    var inactiveNotchHeight: Double {
        get { Defaults[Self.inactiveNotchHeightKey] }
        set { Defaults[Self.inactiveNotchHeightKey] = newValue }
    }

    @Setting<Bool>(key: "useInactiveNotchHeight", default: false)
    var useInactiveNotchHeight: Bool {
        get { Defaults[Self.useInactiveNotchHeightKey] }
        set { Defaults[Self.useInactiveNotchHeightKey] = newValue }
    }

    @Setting<WindowHeightMode>(key: "notchHeightMode", default: WindowHeightMode.matchRealNotchSize)
    var notchHeightMode: WindowHeightMode {
        get { Defaults[Self.notchHeightModeKey] }
        set { Defaults[Self.notchHeightModeKey] = newValue }
    }

    @Setting<WindowHeightMode>(key: "nonNotchHeightMode", default: WindowHeightMode.matchMenuBar)
    var nonNotchHeightMode: WindowHeightMode {
        get { Defaults[Self.nonNotchHeightModeKey] }
        set { Defaults[Self.nonNotchHeightModeKey] = newValue }
    }

    @Setting<Double>(key: "nonNotchHeight", default: 32)
    var nonNotchHeight: Double {
        get { Defaults[Self.nonNotchHeightKey] }
        set { Defaults[Self.nonNotchHeightKey] = newValue }
    }

    @Setting<Double>(key: "notchHeight", default: 32)
    var notchHeight: Double {
        get { Defaults[Self.notchHeightKey] }
        set { Defaults[Self.notchHeightKey] = newValue }
    }

    @Setting<Bool>(key: "showOnLockScreen", default: false)
    var showOnLockScreen: Bool {
        get { Defaults[Self.showOnLockScreenKey] }
        set { Defaults[Self.showOnLockScreenKey] = newValue }
    }

    @Setting<Bool>(key: "hideFromScreenRecording", default: false)
    var hideFromScreenRecording: Bool {
        get { Defaults[Self.hideFromScreenRecordingKey] }
        set { Defaults[Self.hideFromScreenRecordingKey] = newValue }
    }

    @Setting<Bool>(key: "alwaysShowTabs", default: true)
    var alwaysShowTabs: Bool {
        get { Defaults[Self.alwaysShowTabsKey] }
        set { Defaults[Self.alwaysShowTabsKey] = newValue }
    }

    @Setting<Bool>(key: "openLastTabByDefault", default: false)
    var openLastTabByDefault: Bool {
        get { Defaults[Self.openLastTabByDefaultKey] }
        set { Defaults[Self.openLastTabByDefaultKey] = newValue }
    }

    @Setting<Bool>(key: "showMirror", default: false)
    var showMirror: Bool {
        get { Defaults[Self.showMirrorKey] }
        set { Defaults[Self.showMirrorKey] = newValue }
    }

    @Setting<MirrorShapeEnum>(key: "mirrorShape", default: MirrorShapeEnum.rectangle)
    var mirrorShape: MirrorShapeEnum {
        get { Defaults[Self.mirrorShapeKey] }
        set { Defaults[Self.mirrorShapeKey] = newValue }
    }

    @Setting<Bool>(key: "settingsIconInNotch", default: true)
    var settingsIconInNotch: Bool {
        get { Defaults[Self.settingsIconInNotchKey] }
        set { Defaults[Self.settingsIconInNotchKey] = newValue }
    }

    @Setting<Bool>(key: "lightingEffect", default: true)
    var lightingEffect: Bool {
        get { Defaults[Self.lightingEffectKey] }
        set { Defaults[Self.lightingEffectKey] = newValue }
    }

    @Setting<Bool>(key: "enableShadow", default: true)
    var enableShadow: Bool {
        get { Defaults[Self.enableShadowKey] }
        set { Defaults[Self.enableShadowKey] = newValue }
    }

    @Setting<Bool>(key: "cornerRadiusScaling", default: true)
    var cornerRadiusScaling: Bool {
        get { Defaults[Self.cornerRadiusScalingKey] }
        set { Defaults[Self.cornerRadiusScalingKey] = newValue }
    }

    @Setting<URL?>(key: "backgroundImageURL", default: nil)
    var backgroundImageURL: URL? {
        get { Defaults[Self.backgroundImageURLKey] }
        set { Defaults[Self.backgroundImageURLKey] = newValue }
    }

    @Setting<Bool>(key: "liquidGlassEffect", default: false)
    var liquidGlassEffect: Bool {
        get { Defaults[Self.liquidGlassEffectKey] }
        set { Defaults[Self.liquidGlassEffectKey] = newValue }
    }

    @Setting<LiquidGlassStyle>(key: "liquidGlassStyle", default: .default)
    var liquidGlassStyle: LiquidGlassStyle {
        get { Defaults[Self.liquidGlassStyleKey] }
        set { Defaults[Self.liquidGlassStyleKey] = newValue }
    }

    @Setting<Double>(key: "liquidGlassBlurRadius", default: 20.0)
    var liquidGlassBlurRadius: Double {
        get { Defaults[Self.liquidGlassBlurRadiusKey] }
        set { Defaults[Self.liquidGlassBlurRadiusKey] = newValue }
    }

    @Setting<Bool>(key: "showNotHumanFace", default: false)
    var showNotHumanFace: Bool {
        get { Defaults[Self.showNotHumanFaceKey] }
        set { Defaults[Self.showNotHumanFaceKey] = newValue }
    }

    @Setting<Bool>(key: "tileShowLabels", default: false)
    var tileShowLabels: Bool {
        get { Defaults[Self.tileShowLabelsKey] }
        set { Defaults[Self.tileShowLabelsKey] = newValue }
    }

    @Setting<Bool>(key: "showCalendar", default: true)
    var showCalendar: Bool {
        get { Defaults[Self.showCalendarKey] }
        set { Defaults[Self.showCalendarKey] = newValue }
    }

    @Setting<Bool>(key: "showWeather", default: true)
    var showWeather: Bool {
        get { Defaults[Self.showWeatherKey] }
        set { Defaults[Self.showWeatherKey] = newValue }
    }

    @Setting<Bool>(key: "showHabitTracker", default: true)
    var showHabitTracker: Bool {
        get { Defaults[Self.showHabitTrackerKey] }
        set { Defaults[Self.showHabitTrackerKey] = newValue }
    }

    @Setting<Bool>(key: "showPomodoro", default: true)
    var showPomodoro: Bool {
        get { Defaults[Self.showPomodoroKey] }
        set { Defaults[Self.showPomodoroKey] = newValue }
    }

    @Setting<Bool>(key: "showTeleprompter", default: true)
    var showTeleprompter: Bool {
        get { Defaults[Self.showTeleprompterKey] }
        set { Defaults[Self.showTeleprompterKey] = newValue }
    }

    @Setting<WeatherSource>(key: "weatherSource", default: .auto)
    var weatherSource: WeatherSource {
        get { Defaults[Self.weatherSourceKey] }
        set { Defaults[Self.weatherSourceKey] = newValue }
    }

    @Setting<String>(key: "openWeatherMapApiKey", default: "")
    var openWeatherMapApiKey: String {
        get { Defaults[Self.openWeatherMapApiKeyKey] }
        set { Defaults[Self.openWeatherMapApiKeyKey] = newValue }
    }

    @Setting<Bool>(key: "hideCompletedReminders", default: true)
    var hideCompletedReminders: Bool {
        get { Defaults[Self.hideCompletedRemindersKey] }
        set { Defaults[Self.hideCompletedRemindersKey] = newValue }
    }

    @Setting<SliderColorEnum>(key: "sliderUseAlbumArtColor", default: SliderColorEnum.white)
    var sliderColor: SliderColorEnum {
        get { Defaults[Self.sliderColorKey] }
        set { Defaults[Self.sliderColorKey] = newValue }
    }

    @Setting<Bool>(key: "playerColorTinting", default: true)
    var playerColorTinting: Bool {
        get { Defaults[Self.playerColorTintingKey] }
        set { Defaults[Self.playerColorTintingKey] = newValue }
    }

    @Setting<Bool>(key: "enableGestures", default: true)
    var enableGestures: Bool {
        get { Defaults[Self.enableGesturesKey] }
        set { Defaults[Self.enableGesturesKey] = newValue }
    }

    @Setting<Bool>(key: "closeGestureEnabled", default: true)
    var closeGestureEnabled: Bool {
        get { Defaults[Self.closeGestureEnabledKey] }
        set { Defaults[Self.closeGestureEnabledKey] = newValue }
    }

    @Setting<CGFloat>(key: "gestureSensitivity", default: 200.0)
    var gestureSensitivity: CGFloat {
        get { Defaults[Self.gestureSensitivityKey] }
        set { Defaults[Self.gestureSensitivityKey] = newValue }
    }

    @Setting<Bool>(key: "coloredSpectrogram", default: true)
    var coloredSpectrogram: Bool {
        get { Defaults[Self.coloredSpectrogramKey] }
        set { Defaults[Self.coloredSpectrogramKey] = newValue }
    }

    @Setting<Bool>(key: "enableSneakPeek", default: false)
    var enableSneakPeek: Bool {
        get { Defaults[Self.enableSneakPeekKey] }
        set { Defaults[Self.enableSneakPeekKey] = newValue }
    }

    @Setting<SneakPeekStyle>(key: "sneakPeekStyles", default: .standard)
    var sneakPeekStyles: SneakPeekStyle {
        get { Defaults[Self.sneakPeekStylesKey] }
        set { Defaults[Self.sneakPeekStylesKey] = newValue }
    }

    @Setting<Double>(key: "sneakPeakDuration", default: 1.5)
    var sneakPeakDuration: Double {
        get { Defaults[Self.sneakPeakDurationKey] }
        set { Defaults[Self.sneakPeakDurationKey] = newValue }
    }

    @Setting<Mood>(key: "selectedMood", default: .neutral)
    var selectedMood: Mood {
        get { Defaults[Self.selectedMoodKey] }
        set { Defaults[Self.selectedMoodKey] = newValue }
    }

    @Setting<Double>(key: "waitInterval", default: 3)
    var waitInterval: Double {
        get { Defaults[Self.waitIntervalKey] }
        set { Defaults[Self.waitIntervalKey] = newValue }
    }

    @Setting<Bool>(key: "showShuffleAndRepeat", default: false)
    var showShuffleAndRepeat: Bool {
        get { Defaults[Self.showShuffleAndRepeatKey] }
        set { Defaults[Self.showShuffleAndRepeatKey] = newValue }
    }

    @Setting<Bool>(key: "enableLyrics", default: false)
    var enableLyrics: Bool {
        get { Defaults[Self.enableLyricsKey] }
        set { Defaults[Self.enableLyricsKey] = newValue }
    }

    @Setting<[MusicControlButton]>(key: "musicControlSlots", default: MusicControlButton.defaultLayout)
    var musicControlSlots: [MusicControlButton] {
        get { Defaults[Self.musicControlSlotsKey] }
        set { Defaults[Self.musicControlSlotsKey] = newValue }
    }

    @Setting<Int>(key: "musicControlSlotLimit", default: MusicControlButton.defaultLayout.count)
    var musicControlSlotLimit: Int {
        get { Defaults[Self.musicControlSlotLimitKey] }
        set { Defaults[Self.musicControlSlotLimitKey] = newValue }
    }

    @Setting<URL?>(key: "selectedVisualizerURL", default: nil)
    var selectedVisualizerURL: URL? {
        get { Defaults[Self.selectedVisualizerURLKey] }
        set { Defaults[Self.selectedVisualizerURLKey] = newValue }
    }

    @Setting<Double>(key: "selectedVisualizerSpeed", default: 1.0)
    var selectedVisualizerSpeed: Double {
        get { Defaults[Self.selectedVisualizerSpeedKey] }
        set { Defaults[Self.selectedVisualizerSpeedKey] = newValue }
    }

    @Setting<Bool>(key: "ambientVisualizerEnabled", default: false)
    var ambientVisualizerEnabled: Bool {
        get { Defaults[Self.ambientVisualizerEnabledKey] }
        set { Defaults[Self.ambientVisualizerEnabledKey] = newValue }
    }

    @Setting<CGFloat>(key: "ambientVisualizerHeight", default: 110)
    var ambientVisualizerHeight: CGFloat {
        get { Defaults[Self.ambientVisualizerHeightKey] }
        set { Defaults[Self.ambientVisualizerHeightKey] = newValue }
    }

    @Setting<AmbientVisualizerMode>(key: "ambientVisualizerMode", default: .simulated)
    var ambientVisualizerMode: AmbientVisualizerMode {
        get { Defaults[Self.ambientVisualizerModeKey] }
        set { Defaults[Self.ambientVisualizerModeKey] = newValue }
    }

    @Setting<Double>(key: "visualizerSensitivity", default: 0.5)
    var visualizerSensitivity: Double {
        get { Defaults[Self.visualizerSensitivityKey] }
        set { Defaults[Self.visualizerSensitivityKey] = newValue }
    }

    @Setting<Bool>(key: "visualizerShowWhenPaused", default: false)
    var visualizerShowWhenPaused: Bool {
        get { Defaults[Self.visualizerShowWhenPausedKey] }
        set { Defaults[Self.visualizerShowWhenPausedKey] = newValue }
    }

    @Setting<VisualizerBandCount>(key: "visualizerBandCount", default: .thirtyTwo)
    var visualizerBandCount: VisualizerBandCount {
        get { Defaults[Self.visualizerBandCountKey] }
        set { Defaults[Self.visualizerBandCountKey] = newValue }
    }

    @Setting<Bool>(key: "showPowerStatusNotifications", default: true)
    var showPowerStatusNotifications: Bool {
        get { Defaults[Self.showPowerStatusNotificationsKey] }
        set { Defaults[Self.showPowerStatusNotificationsKey] = newValue }
    }

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

    @Setting<OptionKeyAction>(key: "optionKeyAction", default: OptionKeyAction.openSettings)
    var optionKeyAction: OptionKeyAction {
        get { Defaults[Self.optionKeyActionKey] }
        set { Defaults[Self.optionKeyActionKey] = newValue }
    }

    @Setting<Bool>(key: "shelfEnabled", default: true)
    var shelfEnabled: Bool {
        get { Defaults[Self.shelfEnabledKey] }
        set { Defaults[Self.shelfEnabledKey] = newValue }
    }

    @Setting<Bool>(key: "openShelfByDefault", default: false)
    var openShelfByDefault: Bool {
        get { Defaults[Self.openShelfByDefaultKey] }
        set { Defaults[Self.openShelfByDefaultKey] = newValue }
    }

    @Setting<Bool>(key: "shelfTapToOpen", default: true)
    var shelfTapToOpen: Bool {
        get { Defaults[Self.shelfTapToOpenKey] }
        set { Defaults[Self.shelfTapToOpenKey] = newValue }
    }

    @Setting<String>(key: "quickShareProvider", default: "System Share Menu")
    var quickShareProvider: String {
        get { Defaults[Self.quickShareProviderKey] }
        set { Defaults[Self.quickShareProviderKey] = newValue }
    }

    @Setting<Bool>(key: "copyOnDrag", default: false)
    var copyOnDrag: Bool {
        get { Defaults[Self.copyOnDragKey] }
        set { Defaults[Self.copyOnDragKey] = newValue }
    }

    @Setting<Bool>(key: "autoRemoveShelfItems", default: false)
    var autoRemoveShelfItems: Bool {
        get { Defaults[Self.autoRemoveShelfItemsKey] }
        set { Defaults[Self.autoRemoveShelfItemsKey] = newValue }
    }

    @Setting<Bool>(key: "expandedDragDetection", default: true)
    var expandedDragDetection: Bool {
        get { Defaults[Self.expandedDragDetectionKey] }
        set { Defaults[Self.expandedDragDetectionKey] = newValue }
    }

    @Setting<TimeInterval>(key: "shelfHoverDelay", default: 4.0)
    var shelfHoverDelay: TimeInterval {
        get { Defaults[Self.shelfHoverDelayKey] }
        set { Defaults[Self.shelfHoverDelayKey] = newValue }
    }

    @Setting<CalendarSelectionState>(key: "calendarSelectionState", default: .all)
    var calendarSelectionState: CalendarSelectionState {
        get { Defaults[Self.calendarSelectionStateKey] }
        set { Defaults[Self.calendarSelectionStateKey] = newValue }
    }

    @Setting<Bool>(key: "hideAllDayEvents", default: false)
    var hideAllDayEvents: Bool {
        get { Defaults[Self.hideAllDayEventsKey] }
        set { Defaults[Self.hideAllDayEventsKey] = newValue }
    }

    @Setting<Bool>(key: "showFullEventTitles", default: false)
    var showFullEventTitles: Bool {
        get { Defaults[Self.showFullEventTitlesKey] }
        set { Defaults[Self.showFullEventTitlesKey] = newValue }
    }

    @Setting<Bool>(key: "autoScrollToNextEvent", default: true)
    var autoScrollToNextEvent: Bool {
        get { Defaults[Self.autoScrollToNextEventKey] }
        set { Defaults[Self.autoScrollToNextEventKey] = newValue }
    }

    @Setting<HideNotchOption>(key: "hideNotchOption", default: .nowPlayingOnly)
    var hideNotchOption: HideNotchOption {
        get { Defaults[Self.hideNotchOptionKey] }
        set { Defaults[Self.hideNotchOptionKey] = newValue }
    }

    // Cannot use @Setting — default depends on another Defaults key (circular macro expansion).
    private static let mediaControllerKey = Defaults.Key<MediaControllerType>("mediaController", default: .nowPlaying)
    var mediaController: MediaControllerType {
        get { Defaults[Self.mediaControllerKey] }
        set { Defaults[Self.mediaControllerKey] = newValue }
    }

    @Setting<Bool>(key: "useCustomAccentColor", default: false)
    var useCustomAccentColor: Bool {
        get { Defaults[Self.useCustomAccentColorKey] }
        set { Defaults[Self.useCustomAccentColorKey] = newValue }
    }

    @Setting<Data?>(key: "customAccentColorData", default: nil)
    var customAccentColorData: Data? {
        get { Defaults[Self.customAccentColorDataKey] }
        set { Defaults[Self.customAccentColorDataKey] = newValue }
    }

    @Setting<Bool>(key: "hideTitleBar", default: true)
    var hideTitleBar: Bool {
        get { Defaults[Self.hideTitleBarKey] }
        set { Defaults[Self.hideTitleBarKey] = newValue }
    }

    @Setting<Bool>(key: "hideNonNotchedFromMissionControl", default: true)
    var hideNonNotchedFromMissionControl: Bool {
        get { Defaults[Self.hideNonNotchedFromMissionControlKey] }
        set { Defaults[Self.hideNonNotchedFromMissionControlKey] = newValue }
    }

    @Setting<Bool>(key: "isNowPlayingDeprecated", default: false)
    var isNowPlayingDeprecated: Bool {
        get { Defaults[Self.isNowPlayingDeprecatedKey] }
        set { Defaults[Self.isNowPlayingDeprecatedKey] = newValue }
    }

    @Setting<Bool>(key: "didClearLegacyURLCache_v1", default: false)
    var didClearLegacyURLCacheV1: Bool {
        get { Defaults[Self.didClearLegacyURLCacheV1Key] }
        set { Defaults[Self.didClearLegacyURLCacheV1Key] = newValue }
    }

    @Setting<Bool>(key: "enableAI", default: true)
    var enableAI: Bool {
        get { Defaults[Self.enableAIKey] }
        set { Defaults[Self.enableAIKey] = newValue }
    }

    @Setting<Bool>(key: "obsidianSyncEnabled", default: false)
    var obsidianSyncEnabled: Bool {
        get { Defaults[Self.obsidianSyncEnabledKey] }
        set { Defaults[Self.obsidianSyncEnabledKey] = newValue }
    }

    @Setting<String?>(key: "obsidianVaultPath", default: nil)
    var obsidianVaultPath: String? {
        get { Defaults[Self.obsidianVaultPathKey] }
        set { Defaults[Self.obsidianVaultPathKey] = newValue }
    }

    // MARK: - One-Time Migrations
    /// Returns `true` if the legacy URL cache still needs to be cleared, and marks it as done.
    func consumeLegacyCacheCleanupFlag() -> Bool {
        if !Defaults[Self.didClearLegacyURLCacheV1Key] {
            Defaults[Self.didClearLegacyURLCacheV1Key] = true
            return true
        }
        return false
    }
}
