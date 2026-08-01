//
//  NotchSettingsSubProtocols.swift
//  machNotch
//

import Foundation

// MARK: - HUD Settings

@MainActor
public protocol HUDSettings {
    var showInlineHUD: Bool { get }
    var hudReplacement: Bool { get set }
    var showOpenNotchHUD: Bool { get set }
    var showOpenNotchHUDPercentage: Bool { get set }
    var showClosedNotchHUDPercentage: Bool { get set }
    var showBatteryPercentage: Bool { get set }
    var inlineHUD: Bool { get set }
    var optionKeyAction: OptionKeyAction { get set }
    var enableGradient: Bool { get set }
    var systemEventIndicatorUseAccent: Bool { get set }
    var systemEventIndicatorShadow: Bool { get set }
    var currentMicStatus: Bool { get set }
}

// MARK: - Battery Settings

@MainActor
public protocol BatterySettings {
    var showPowerStatusNotifications: Bool { get set }
    var showBatteryIndicator: Bool { get set }
    var showPowerStatusIcons: Bool { get set }
    var powerStatusNotificationSound: String { get set }
    var lowBatteryNotificationLevel: Int { get set }
    var lowBatteryNotificationSound: String { get set }
    var highBatteryNotificationLevel: Int { get set }
    var highBatteryNotificationSound: String { get set }
}

// MARK: - Appearance Settings

@MainActor
public protocol AppearanceSettings {
    var alwaysShowTabs: Bool { get set }
    var showNotHumanFace: Bool { get set }
    var lightingEffect: Bool { get set }
    var liquidGlassEffect: Bool { get set }
    var liquidGlassStyle: LiquidGlassStyle { get set }
    var liquidGlassBlurRadius: Double { get set }
    var backgroundImageURL: URL? { get set }
    var enableShadow: Bool { get set }
    var cornerRadiusScaling: Bool { get set }
    var settingsIconInNotch: Bool { get set }
    var menubarIcon: Bool { get set }
}

// MARK: - Media Settings

@MainActor
public protocol MediaSettings {
    /// Whether the NowPlaying API is deprecated on this macOS version.
    var isNowPlayingDeprecated: Bool { get set }
    var musicLiveActivityEnabled: Bool { get set }
    var enableSneakPeek: Bool { get set }
    var sneakPeekStyles: SneakPeekStyle { get set }
    var sneakPeakDuration: Double { get set }
    var coloredSpectrogram: Bool { get set }
    var playerColorTinting: Bool { get set }
    var sliderColor: SliderColorEnum { get set }
    var enableLyrics: Bool { get set }
    var selectedMood: Mood { get set }
    var waitInterval: Double { get set }
    var hideNotchOption: HideNotchOption { get set }
    var mediaController: MediaControllerType { get set }
    var mirrorShape: MirrorShapeEnum { get set }
    var selectedWebcamDeviceID: String { get set }
    var musicControlSlots: [MusicControlButton] { get set }
    var selectedVisualizerURL: URL? { get set }
    var selectedVisualizerSpeed: Double { get set }
    var ambientVisualizerEnabled: Bool { get set }
    var ambientVisualizerHeight: CGFloat { get set }
    var ambientVisualizerMode: AmbientVisualizerMode { get set }
    var visualizerSensitivity: Double { get set }
    var visualizerShowWhenPaused: Bool { get set }
    var visualizerBandCount: VisualizerBandCount { get set }
}

// MARK: - Gesture Settings

@MainActor
public protocol GestureSettings {
    var enableGestures: Bool { get set }
    var closeGestureEnabled: Bool { get set }
    var gestureSensitivity: CGFloat { get set }
    var openNotchOnHover: Bool { get set }
    var minimumHoverDuration: TimeInterval { get set }
}

// MARK: - Shelf Settings

@MainActor
public protocol ShelfSettings {
    var shelfEnabled: Bool { get set }
    var openShelfByDefault: Bool { get set }
    var shelfTapToOpen: Bool { get set }
    var expandedDragDetection: Bool { get set }
    var copyOnDrag: Bool { get set }
    var autoRemoveShelfItems: Bool { get set }
    var quickShareProvider: String { get set }
    var shelfHoverDelay: TimeInterval { get set }
}

// MARK: - Display Settings

@MainActor
public protocol DisplaySettings: AnyObject {
    var openLastTabByDefault: Bool { get set }
    var preferredScreenUUID: String? { get set }
    var showOnAllDisplays: Bool { get set }
    var automaticallySwitchDisplay: Bool { get set }
    var hideTitleBar: Bool { get set }
    var extendHoverArea: Bool { get set }
    var showOnLockScreen: Bool { get set }
    var hideFromScreenRecording: Bool { get set }
    var hideNonNotchedFromMissionControl: Bool { get set }
    var useCustomAccentColor: Bool { get set }
    var customAccentColorData: Data? { get set }
    var releaseName: String { get }
    var nonNotchHeight: Double { get set }
    var nonNotchHeightMode: WindowHeightMode { get set }
    var notchHeight: Double { get set }
    var notchHeightMode: WindowHeightMode { get set }
    var inactiveNotchHeight: Double { get set }
    var useInactiveNotchHeight: Bool { get set }
}

// MARK: - Widget Settings (Feature Toggles)

@MainActor
public protocol WidgetSettings {
    var showMirror: Bool { get set }
    var showCalendar: Bool { get set }
    var showWeather: Bool { get set }
    var weatherSource: WeatherSource { get set }
    var openWeatherMapApiKey: String { get set }
    var showHabitTracker: Bool { get set }
    var showPomodoro: Bool { get set }
    var showTeleprompter: Bool { get set }
    var obsidianSyncEnabled: Bool { get set }
    var obsidianVaultPath: String? { get set }
}

// MARK: - Calendar Settings

@MainActor
public protocol NotchCalendarSettings {
    var enableHaptics: Bool { get set }
    var hideCompletedReminders: Bool { get set }
    var hideAllDayEvents: Bool { get set }
    var autoScrollToNextEvent: Bool { get set }
    var showFullEventTitles: Bool { get set }
    var calendarSelectionState: CalendarSelectionState { get set }
}

// MARK: - Notification Settings

@MainActor
public protocol NotificationSettings {
    var showShelfNotifications: Bool { get set }
    var showSystemNotifications: Bool { get set }
    var showInfoNotifications: Bool { get set }
    var notificationDeliveryStyle: NotificationDeliveryStyle { get set }
    var notificationSoundEnabled: Bool { get set }
    var respectDoNotDisturb: Bool { get set }
    var notificationRetentionDays: Int { get set }
    var storedNotifications: [NotchNotification] { get set }
}

// MARK: - General App Settings

@MainActor
public protocol GeneralAppSettings {
    var firstLaunch: Bool { get set }
    var showWhatsNew: Bool { get set }
    var isAIEnabled: Bool { get set }
}

@MainActor
public protocol LocalAISettings: GeneralAppSettings {
    var omlxProviderEnabled: Bool { get set }
    var omlxProviderHost: String { get set }
    var omlxPreferredModelId: String? { get set }
    var omlxAllowNonLocalhostHost: Bool { get set }
}

// MARK: - Coordinator Settings

@MainActor
public protocol CoordinatorSettings: AnyObject, GeneralAppSettings, HUDSettings, MediaSettings,
    AppearanceSettings, DisplaySettings, ShelfSettings
{}

// MARK: - Bluetooth Settings

@MainActor
public protocol BluetoothSettings {
    var enableBluetoothSneakPeek: Bool { get set }
    var bluetoothSneakPeekStyle: SneakPeekStyle { get set }
    var bluetoothDeviceIconMappings: [BluetoothDeviceIconMapping] { get set }
}
