//
//  DefaultsNotchSettings+Plugins.swift
//  boringNotch
//

import Foundation
import Defaults

@MainActor extension DefaultsNotchSettings {
    // MARK: - Gesture Settings
    var enableGestures: Bool {
        get { Defaults[.enableGestures] }
        set { Defaults[.enableGestures] = newValue }
    }
    var closeGestureEnabled: Bool {
        get { Defaults[.closeGestureEnabled] }
        set { Defaults[.closeGestureEnabled] = newValue }
    }
    var gestureSensitivity: CGFloat {
        get { Defaults[.gestureSensitivity] }
        set { Defaults[.gestureSensitivity] = newValue }
    }
    var openNotchOnHover: Bool {
        get { Defaults[.openNotchOnHover] }
        set { Defaults[.openNotchOnHover] = newValue }
    }
    var minimumHoverDuration: TimeInterval {
        get { Defaults[.minimumHoverDuration] }
        set { Defaults[.minimumHoverDuration] = newValue }
    }

    // MARK: - Shelf Settings
    var boringShelf: Bool {
        get { Defaults[.boringShelf] }
        set { Defaults[.boringShelf] = newValue }
    }
    var openShelfByDefault: Bool {
        get { Defaults[.openShelfByDefault] }
        set { Defaults[.openShelfByDefault] = newValue }
    }
    var shelfTapToOpen: Bool {
        get { Defaults[.shelfTapToOpen] }
        set { Defaults[.shelfTapToOpen] = newValue }
    }
    var expandedDragDetection: Bool {
        get { Defaults[.expandedDragDetection] }
        set { Defaults[.expandedDragDetection] = newValue }
    }
    var copyOnDrag: Bool {
        get { Defaults[.copyOnDrag] }
        set { Defaults[.copyOnDrag] = newValue }
    }
    var autoRemoveShelfItems: Bool {
        get { Defaults[.autoRemoveShelfItems] }
        set { Defaults[.autoRemoveShelfItems] = newValue }
    }
    var quickShareProvider: String {
        get { Defaults[.quickShareProvider] }
        set { Defaults[.quickShareProvider] = newValue }
    }
    var shelfHoverDelay: TimeInterval {
        get { Defaults[.shelfHoverDelay] }
        set { Defaults[.shelfHoverDelay] = newValue }
    }

    // MARK: - Widget Settings
    var showMirror: Bool {
        get { Defaults[.showMirror] }
        set { Defaults[.showMirror] = newValue }
    }
    var showCalendar: Bool {
        get { Defaults[.showCalendar] }
        set { Defaults[.showCalendar] = newValue }
    }
    var showWeather: Bool {
        get { Defaults[.showWeather] }
        set { Defaults[.showWeather] = newValue }
    }
    var showHabitTracker: Bool {
        get { Defaults[.showHabitTracker] }
        set { Defaults[.showHabitTracker] = newValue }
    }
    var showPomodoro: Bool {
        get { Defaults[.showPomodoro] }
        set { Defaults[.showPomodoro] = newValue }
    }
    var showTeleprompter: Bool {
        get { Defaults[.showTeleprompter] }
        set { Defaults[.showTeleprompter] = newValue }
    }
    var openWeatherMapApiKey: String {
        get { Defaults[.openWeatherMapApiKey] }
        set { Defaults[.openWeatherMapApiKey] = newValue }
    }

    // MARK: - Calendar Settings
    var enableHaptics: Bool {
        get { Defaults[.enableHaptics] }
        set { Defaults[.enableHaptics] = newValue }
    }
    var hideCompletedReminders: Bool {
        get { Defaults[.hideCompletedReminders] }
        set { Defaults[.hideCompletedReminders] = newValue }
    }
    var hideAllDayEvents: Bool {
        get { Defaults[.hideAllDayEvents] }
        set { Defaults[.hideAllDayEvents] = newValue }
    }
    var autoScrollToNextEvent: Bool {
        get { Defaults[.autoScrollToNextEvent] }
        set { Defaults[.autoScrollToNextEvent] = newValue }
    }
    var showFullEventTitles: Bool {
        get { Defaults[.showFullEventTitles] }
        set { Defaults[.showFullEventTitles] = newValue }
    }
    var calendarSelectionState: CalendarSelectionState {
        get { Defaults[.calendarSelectionState] }
        set { Defaults[.calendarSelectionState] = newValue }
    }

    // MARK: - Bluetooth Settings
    var enableBluetoothSneakPeek: Bool {
        get { Defaults[.enableBluetoothSneakPeek] }
        set { Defaults[.enableBluetoothSneakPeek] = newValue }
    }
    var bluetoothSneakPeekStyle: SneakPeekStyle {
        get { Defaults[.bluetoothSneakPeekStyle] }
        set { Defaults[.bluetoothSneakPeekStyle] = newValue }
    }
    var bluetoothDeviceIconMappings: [BluetoothDeviceIconMapping] {
        get { Defaults[.bluetoothDeviceIconMappings] }
        set { Defaults[.bluetoothDeviceIconMappings] = newValue }
    }
}
