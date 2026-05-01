//
//  PluginSettings.swift
//  boringNotch
//
//  Namespaced settings wrapper for plugins.
//  Each plugin gets its own namespace in Defaults.
//

import Foundation
import Combine
import Defaults

// MARK: - Plugin Settings

/// Wraps Defaults with plugin-specific namespace.
/// Each plugin gets keys prefixed with "plugin.{pluginId}."
@MainActor
final class PluginSettings: Observable {
    private let pluginId: String
    private let prefix: String

    /// Settings change publisher
    private let changesSubject = PassthroughSubject<String, Never>()
    var changesPublisher: AnyPublisher<String, Never> {
        changesSubject.eraseToAnyPublisher()
    }

    init(pluginId: String) {
        // Sanitize pluginId to ensure valid keys (no dots)
        self.pluginId = pluginId.replacingOccurrences(of: ".", with: "_")
        self.prefix = "plugin_\(self.pluginId)_"
    }

    // MARK: - Standard Settings

    /// Whether this plugin is enabled
    var isEnabled: Bool {
        get { get("enabled", default: true) }
        set { set("enabled", value: newValue) }
    }

    /// Display order in tab bar (lower = earlier)
    var displayOrder: Int {
        get { get("displayOrder", default: 100) }
        set { set("displayOrder", value: newValue) }
    }

    /// Whether to show in closed notch
    var showInClosedNotch: Bool {
        get { get("showInClosedNotch", default: true) }
        set { set("showInClosedNotch", value: newValue) }
    }

    // MARK: - Generic Accessors

    /// Get a setting value with default
    func get<T: Defaults.Serializable>(_ key: String, default defaultValue: T) -> T {
        let fullKey = makeKey(key, default: defaultValue)
        return Defaults[fullKey]
    }

    /// Set a setting value
    func set<T: Defaults.Serializable>(_ key: String, value: T) {
        let fullKey = makeKey(key, default: value)
        Defaults[fullKey] = value
        changesSubject.send(key)
    }

    /// Check if a setting exists
    func exists(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: prefix + key) != nil
    }

    /// Remove a setting
    func remove(_ key: String) {
        UserDefaults.standard.removeObject(forKey: prefix + key)
        changesSubject.send(key)
    }

    /// Remove all settings for this plugin
    func removeAll() {
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(prefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Observation

    /// Observe changes to a specific setting
    func observe<T: Defaults.Serializable>(
        _ key: String,
        default defaultValue: T
    ) -> AnyPublisher<T, Never> {
        let fullKey = makeKey(key, default: defaultValue)
        return Defaults.publisher(fullKey)
            .map(\.newValue)
            .eraseToAnyPublisher()
    }

    // MARK: - Private Helpers

    private func makeKey<T: Defaults.Serializable>(_ key: String, default defaultValue: T) -> Defaults.Key<T> {
        Defaults.Key<T>(prefix + key, default: defaultValue)
    }
}

// MARK: - Migration Support

/// Handles migration from old settings keys to plugin-namespaced keys
struct PluginSettingsMigration {
    /// Key indicating migration has been completed
    private static let migrationKey = Defaults.Key<Bool>("pluginSettingsMigrated_v2", default: false)

    /// Perform migration if needed
    static func migrateIfNeeded() {
        guard !Defaults[migrationKey] else { return }

        // Music plugin
        migrateIfExists(from: "showMusicLiveActivity", to: "plugin_com_boringnotch_music_showLiveActivity")
        migrateIfExists(from: "enableSneakPeek", to: "plugin_com_boringnotch_music_enableSneakPeek")
        migrateIfExists(from: "waitInterval", to: "plugin_com_boringnotch_music_waitInterval")

        // Calendar plugin
        migrateIfExists(from: "showCalendar", to: "plugin_com_boringnotch_calendar_enabled")

        // Shelf plugin
        migrateIfExists(from: "boringShelf", to: "plugin_com_boringnotch_shelf_enabled")

        // Weather plugin
        migrateIfExists(from: "showWeather", to: "plugin_com_boringnotch_weather_enabled")

        // Battery plugin
        migrateIfExists(from: "showBattery", to: "plugin_com_boringnotch_battery_enabled")
        migrateIfExists(from: "chargingInfoAllowed", to: "plugin_com_boringnotch_battery_showChargingInfo")
        
        // Migrate from v1 (dot-separated) to v2 (underscore-separated) if needed
        // This is a best-effort migration for users who might have used the broken version
        migrateDotKeysToUnderscore()

        Defaults[migrationKey] = true
    }

    private static func migrateIfExists(from oldKey: String, to newKey: String) {
        guard let value = UserDefaults.standard.object(forKey: oldKey) else { return }
        UserDefaults.standard.set(value, forKey: newKey)
        // Note: We don't delete old keys to allow rollback
    }
    
    private static func migrateDotKeysToUnderscore() {
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix("plugin.") {
            let newKey = key.replacingOccurrences(of: ".", with: "_")
            if let value = UserDefaults.standard.object(forKey: key) {
                UserDefaults.standard.set(value, forKey: newKey)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension PluginSettings {
    /// Set a value only if different from current
    func setIfChanged<T: Defaults.Serializable & Equatable>(_ key: String, value: T, default defaultValue: T) {
        let current = get(key, default: defaultValue)
        if current != value {
            set(key, value: value)
        }
    }
}
