//
//  MockNotchSettings.swift
//  NotchCore
//
//  Mock implementation of NotchSettings for unit testing and previews.
//  All properties are mutable with sensible defaults.
//

import Foundation
import Observation

@MainActor
@Observable
public final class MockNotchSettings: NotchSettings {
    public nonisolated init() {}

    // MARK: - General App Settings
    public var firstLaunch: Bool = true
    public var showWhatsNew: Bool = true
    public var isAIEnabled: Bool = true
    public var omlxProviderEnabled: Bool = false
    public var omlxProviderHost: String = "http://127.0.0.1:8000/v1"
    public var omlxPreferredModelId: String?
    public var omlxAllowNonLocalhostHost: Bool = false

    // MARK: - HUD Settings
    public var currentMicStatus: Bool = true
    public var showInlineHUD: Bool = false
    public var hudReplacement: Bool = false
    public var showOpenNotchHUD: Bool = true
    public var showOpenNotchHUDPercentage: Bool = true
    public var showClosedNotchHUDPercentage: Bool = true
    public var showBatteryPercentage: Bool = true
    public var inlineHUD: Bool = false
    public var optionKeyAction: OptionKeyAction = .none
    public var enableGradient: Bool = true
    public var systemEventIndicatorUseAccent: Bool = true
    public var systemEventIndicatorShadow: Bool = true

    // MARK: - Battery Settings
    public var showPowerStatusNotifications: Bool = true
    public var showBatteryIndicator: Bool = true
    public var showPowerStatusIcons: Bool = true
    public var powerStatusNotificationSound: String = "Disabled"
    public var lowBatteryNotificationLevel: Int = 0
    public var lowBatteryNotificationSound: String = "Disabled"
    public var highBatteryNotificationLevel: Int = 0
    public var highBatteryNotificationSound: String = "Disabled"

    // MARK: - Appearance Settings
    public var alwaysShowTabs: Bool = false
    public var showNotHumanFace: Bool = false
    public var lightingEffect: Bool = true
    public var liquidGlassEffect: Bool = false
    public var liquidGlassStyle: LiquidGlassStyle = .default
    public var liquidGlassBlurRadius: Double = 10.0
    public var backgroundImageURL: URL?
    public var enableShadow: Bool = true
    public var cornerRadiusScaling: Bool = true
    public var settingsIconInNotch: Bool = true
    public var menubarIcon: Bool = true

    // MARK: - Music & Media Settings
    public var musicLiveActivityEnabled: Bool = true
    public var enableSneakPeek: Bool = false
    public var sneakPeekStyles: SneakPeekStyle = .standard
    public var sneakPeakDuration: Double = 1.5
    public var coloredSpectrogram: Bool = true
    public var playerColorTinting: Bool = true
    public var sliderColor: SliderColorEnum = .white
    public var enableLyrics: Bool = true
    public var selectedMood: Mood = .neutral
    public var waitInterval: Double = 5.0
    public var hideNotchOption: HideNotchOption = .never
    public var isNowPlayingDeprecated: Bool = false
    public var mediaController: MediaControllerType = .nowPlaying
    public var mirrorShape: MirrorShapeEnum = .circle
    public var selectedWebcamDeviceID: String = ""
    public var musicControlSlots: [MusicControlButton] = MusicControlButton.defaultLayout
    public var selectedVisualizerURL: URL?
    public var selectedVisualizerSpeed: Double = 1.0
    public var ambientVisualizerEnabled: Bool = false
    public var ambientVisualizerHeight: CGFloat = 110
    public var ambientVisualizerMode: AmbientVisualizerMode = .simulated
    public var visualizerSensitivity: Double = 0.5
    public var visualizerShowWhenPaused: Bool = false
    public var visualizerBandCount: VisualizerBandCount = .thirtyTwo

    // MARK: - Gesture Settings
    public var enableGestures: Bool = true
    public var closeGestureEnabled: Bool = true
    public var gestureSensitivity: CGFloat = 200.0
    public var openNotchOnHover: Bool = true
    public var minimumHoverDuration: TimeInterval = 0.3

    // MARK: - Shelf Settings
    public var shelfEnabled: Bool = true
    public var openShelfByDefault: Bool = false
    public var shelfTapToOpen: Bool = true
    public var expandedDragDetection: Bool = true
    public var copyOnDrag: Bool = false
    public var autoRemoveShelfItems: Bool = false
    public var quickShareProvider: String = "com.apple.share.AirDrop"
    public var shelfHoverDelay: TimeInterval = 4.0

    // MARK: - Display Settings
    public var openLastTabByDefault: Bool = false
    public var preferredScreenUUID: String?
    public var showOnAllDisplays: Bool = false
    public var automaticallySwitchDisplay: Bool = true
    public var hideTitleBar: Bool = false
    public var extendHoverArea: Bool = false
    public var showOnLockScreen: Bool = false
    public var hideFromScreenRecording: Bool = false
    public var hideNonNotchedFromMissionControl: Bool = true
    public var useCustomAccentColor: Bool = false
    public var customAccentColorData: Data?
    public var releaseName: String = "machNotch"
    public var nonNotchHeight: Double = 23.0
    public var nonNotchHeightMode: WindowHeightMode = .matchMenuBar
    public var notchHeight: Double = 38.0
    public var notchHeightMode: WindowHeightMode = .matchRealNotchSize
    public var inactiveNotchHeight: Double = 23.0
    public var useInactiveNotchHeight: Bool = false

    // MARK: - Notes Settings
    public var obsidianSyncEnabled: Bool = false
    public var obsidianVaultPath: String? = nil

    // MARK: - Widget Settings
    public var showMirror: Bool = false
    public var showCalendar: Bool = true
    public var showWeather: Bool = true
    public var showHabitTracker: Bool = false
    public var showPomodoro: Bool = false
    public var showTeleprompter: Bool = true
    public var weatherSource: WeatherSource = .auto
    public var openWeatherMapApiKey: String = ""

    // MARK: - Calendar Settings
    public var enableHaptics: Bool = true
    public var hideCompletedReminders: Bool = false
    public var hideAllDayEvents: Bool = false
    public var autoScrollToNextEvent: Bool = true
    public var showFullEventTitles: Bool = false
    public var calendarSelectionState: CalendarSelectionState = .all

    // MARK: - Notification Settings
    public var showShelfNotifications: Bool = true
    public var showSystemNotifications: Bool = true
    public var showInfoNotifications: Bool = true
    public var notificationDeliveryStyle: NotificationDeliveryStyle = .banner
    public var notificationSoundEnabled: Bool = true
    public var respectDoNotDisturb: Bool = true
    public var notificationRetentionDays: Int = 7
    public var storedNotifications: [NotchNotification] = []

    // MARK: - Bluetooth Settings
    public var enableBluetoothSneakPeek: Bool = true
    public var bluetoothSneakPeekStyle: SneakPeekStyle = .standard
    public var bluetoothDeviceIconMappings: [BluetoothDeviceIconMapping] = []
}
