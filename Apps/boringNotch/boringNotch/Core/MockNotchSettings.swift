//
//  MockNotchSettings.swift
//  boringNotch
//
//  Mock implementation of NotchSettings for unit testing.
//  All properties are mutable with sensible defaults.
//

import Foundation

final class MockNotchSettings: NotchSettings {
    nonisolated init() {}

    // MARK: - General App Settings
    var firstLaunch: Bool = true
    var showWhatsNew: Bool = true
    var isAIEnabled: Bool = true

    // MARK: - HUD Settings
    var currentMicStatus: Bool = true
    var showInlineHUD: Bool = false
    var hudReplacement: Bool = false
    var showOpenNotchHUD: Bool = true
    var showOpenNotchHUDPercentage: Bool = true
    var showClosedNotchHUDPercentage: Bool = true
    var showBatteryPercentage: Bool = true
    var inlineHUD: Bool = false
    var optionKeyAction: OptionKeyAction = .none
    var enableGradient: Bool = true
    var systemEventIndicatorUseAccent: Bool = true
    var systemEventIndicatorShadow: Bool = true

    // MARK: - Battery Settings
    var showPowerStatusNotifications: Bool = true
    var showBatteryIndicator: Bool = true
    var showPowerStatusIcons: Bool = true
    var powerStatusNotificationSound: String = "Disabled"
    var lowBatteryNotificationLevel: Int = 0
    var lowBatteryNotificationSound: String = "Disabled"
    var highBatteryNotificationLevel: Int = 0
    var highBatteryNotificationSound: String = "Disabled"

    // MARK: - Appearance Settings
    var alwaysShowTabs: Bool = false
    var showNotHumanFace: Bool = false
    var lightingEffect: Bool = true
    var liquidGlassEffect: Bool = false
    var liquidGlassStyle: LiquidGlassStyle = .default
    var liquidGlassBlurRadius: Double = 10.0
    var backgroundImageURL: URL?
    var enableShadow: Bool = true
    var cornerRadiusScaling: Bool = true
    var settingsIconInNotch: Bool = true
    var menubarIcon: Bool = true

    // MARK: - Music & Media Settings
    var musicLiveActivityEnabled: Bool = true
    var enableSneakPeek: Bool = false
    var sneakPeekStyles: SneakPeekStyle = .standard
    var sneakPeakDuration: Double = 1.5
    var coloredSpectrogram: Bool = true
    var playerColorTinting: Bool = true
    var sliderColor: SliderColorEnum = .white
    var enableLyrics: Bool = true
    var selectedMood: Mood = .neutral
    var waitInterval: Double = 5.0
    var hideNotchOption: HideNotchOption = .never
    var isNowPlayingDeprecated: Bool = false
    var mediaController: MediaControllerType = .nowPlaying
    var mirrorShape: MirrorShapeEnum = .circle
    var musicControlSlots: [MusicControlButton] = MusicControlButton.defaultLayout
    var selectedVisualizerURL: URL?
    var selectedVisualizerSpeed: Double = 1.0
    var ambientVisualizerEnabled: Bool = false
    var ambientVisualizerHeight: CGFloat = 110
    var ambientVisualizerMode: AmbientVisualizerMode = .simulated
    var visualizerSensitivity: Double = 0.5
    var visualizerShowWhenPaused: Bool = false
    var visualizerBandCount: VisualizerBandCount = .thirtyTwo

    // MARK: - Gesture Settings
    var enableGestures: Bool = true
    var closeGestureEnabled: Bool = true
    var gestureSensitivity: CGFloat = 200.0
    var openNotchOnHover: Bool = true
    var minimumHoverDuration: TimeInterval = 0.3

    // MARK: - Shelf Settings
    var boringShelf: Bool = true
    var openShelfByDefault: Bool = false
    var shelfTapToOpen: Bool = true
    var expandedDragDetection: Bool = true
    var copyOnDrag: Bool = false
    var autoRemoveShelfItems: Bool = false
    var quickShareProvider: String = "com.apple.share.AirDrop"
    var shelfHoverDelay: TimeInterval = 4.0

    // MARK: - Display Settings
    var openLastTabByDefault: Bool = false
    var preferredScreenUUID: String?
    var showOnAllDisplays: Bool = false
    var automaticallySwitchDisplay: Bool = true
    var hideTitleBar: Bool = false
    var extendHoverArea: Bool = false
    var showOnLockScreen: Bool = false
    var hideFromScreenRecording: Bool = false
    var hideNonNotchedFromMissionControl: Bool = true
    var useCustomAccentColor: Bool = false
    var customAccentColorData: Data?
    var releaseName: String = "Boring Notch"
    var nonNotchHeight: Double = 23.0
    var nonNotchHeightMode: WindowHeightMode = .matchMenuBar
    var notchHeight: Double = 38.0
    var notchHeightMode: WindowHeightMode = .matchRealNotchSize
    var inactiveNotchHeight: Double = 23.0
    var useInactiveNotchHeight: Bool = false

    // MARK: - Widget Settings
    var showMirror: Bool = false
    var showCalendar: Bool = true
    var showWeather: Bool = true
    var showHabitTracker: Bool = false
    var showPomodoro: Bool = false
    var showTeleprompter: Bool = true
    var openWeatherMapApiKey: String = ""

    // MARK: - Calendar Settings
    var enableHaptics: Bool = true
    var hideCompletedReminders: Bool = false
    var hideAllDayEvents: Bool = false
    var autoScrollToNextEvent: Bool = true
    var showFullEventTitles: Bool = false
    var calendarSelectionState: CalendarSelectionState = .all

    // MARK: - Notification Settings
    var showShelfNotifications: Bool = true
    var showSystemNotifications: Bool = true
    var showInfoNotifications: Bool = true
    var notificationDeliveryStyle: NotificationDeliveryStyle = .banner
    var notificationSoundEnabled: Bool = true
    var respectDoNotDisturb: Bool = true
    var notificationRetentionDays: Int = 7
    var storedNotifications: [NotchNotification] = []

    // MARK: - Bluetooth Settings
    var enableBluetoothSneakPeek: Bool = true
    var bluetoothSneakPeekStyle: SneakPeekStyle = .standard
    var bluetoothDeviceIconMappings: [BluetoothDeviceIconMapping] = []
}
