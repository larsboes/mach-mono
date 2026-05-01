//
//  NotchSettings.swift
//  boringNotch
//
//  Created as part of Phase 1 architectural refactoring.
//  Abstracts settings access for testability.
//
//  Sub-protocols defined in NotchSettingsSubProtocols.swift
//  Production impl in DefaultsNotchSettings.swift
//  Test mock in MockNotchSettings.swift
//

import Foundation
import SwiftUI

/// Composed protocol inheriting all sub-protocols from NotchSettingsSubProtocols.
/// Consumers that need everything use `NotchSettings`; consumers that only need
/// a subset (e.g., `MediaSettings`) can depend on the narrower protocol instead.
@MainActor
protocol NotchSettings: CoordinatorSettings, BatterySettings, GestureSettings,
    WidgetSettings, NotchCalendarSettings, NotificationSettings, BluetoothSettings {}

// MARK: - Environment Keys

/// Read-only environment key for protocol-based DI (testable with MockNotchSettings)
private struct NotchSettingsKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: any NotchSettings = MockNotchSettings()
}

extension EnvironmentValues {
    /// Read-only settings access for views that don't need binding.
    /// Use `MockNotchSettings()` for testing.
    var settings: any NotchSettings {
        get { self[NotchSettingsKey.self] }
        set { self[NotchSettingsKey.self] = newValue }
    }
}

/// Bindable environment key for settings views that need two-way binding
private struct BindableNotchSettingsKey: EnvironmentKey {
    // Fall back to .shared — SwiftUI may resolve the default during NSHostingView init
    // before .environment(\.bindableSettings, ...) is applied in the modifier chain.
    // A fatalError here crashes the app at launch.
    @MainActor static var defaultValue: DefaultsNotchSettings {
        DefaultsNotchSettings.shared
    }
}

extension EnvironmentValues {
    /// Bindable settings access for views that need two-way binding.
    /// Use with `@Environment(\.bindableSettings) @Bindable var settings`
    var bindableSettings: DefaultsNotchSettings {
        get { self[BindableNotchSettingsKey.self] }
        set { self[BindableNotchSettingsKey.self] = newValue }
    }
}
