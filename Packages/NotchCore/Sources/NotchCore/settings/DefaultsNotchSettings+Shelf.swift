//
//  DefaultsNotchSettings+Shelf.swift
//  NotchCore
//
//  Shelf, calendar, weather, and integration settings.
//

import Defaults
import Foundation
import NotchSettingsMacro

public extension DefaultsNotchSettings {

    // MARK: - Shelf

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

    // MARK: - Calendar

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

    @Setting<Bool>(key: "hideCompletedReminders", default: true)
    var hideCompletedReminders: Bool {
        get { Defaults[Self.hideCompletedRemindersKey] }
        set { Defaults[Self.hideCompletedRemindersKey] = newValue }
    }

    // MARK: - Weather

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

    // MARK: - Integrations

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
}
