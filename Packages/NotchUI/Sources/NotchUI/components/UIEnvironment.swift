//
//  UIEnvironment.swift
//  NotchUI
//
//  Environment keys for sharing layout and animation state.
//

import SwiftUI
import NotchCore

public struct DisplayClosedNotchHeightKey: EnvironmentKey {
    public static let defaultValue: CGFloat = 32.0
}

public struct ContentProgressKey: EnvironmentKey {
    /// Content animation progress (0 = closed, 1 = fully open).
    public static let defaultValue: CGFloat = 0.0
}

public struct IsNotchClosingKey: EnvironmentKey {
    /// Whether the notch is currently in its closing transition.
    public static let defaultValue: Bool = false
}

public struct CornerRadiusScaleFactorKey: EnvironmentKey {
    public static let defaultValue: CGFloat? = nil
}

public struct CornerRadiusInsetsKey: EnvironmentKey {
    public static let defaultValue: CornerRadiusInsets = CornerRadiusInsets(
        opened: (top: 0, bottom: 0),
        closed: (top: 0, bottom: 0)
    )
}

public extension EnvironmentValues {
    var displayClosedNotchHeight: CGFloat {
        get { self[DisplayClosedNotchHeightKey.self] }
        set { self[DisplayClosedNotchHeightKey.self] = newValue }
    }

    var contentProgress: CGFloat {
        get { self[ContentProgressKey.self] }
        set { self[ContentProgressKey.self] = newValue }
    }

    var isNotchClosing: Bool {
        get { self[IsNotchClosingKey.self] }
        set { self[IsNotchClosingKey.self] = newValue }
    }

    var cornerRadiusScaleFactor: CGFloat? {
        get { self[CornerRadiusScaleFactorKey.self] }
        set { self[CornerRadiusScaleFactorKey.self] = newValue }
    }

    var cornerRadiusInsets: CornerRadiusInsets {
        get { self[CornerRadiusInsetsKey.self] }
        set { self[CornerRadiusInsetsKey.self] = newValue }
    }

    var settings: any NotchSettings {
        get { self[NotchSettingsKey.self] }
        set { self[NotchSettingsKey.self] = newValue }
    }

    var bindableSettings: DefaultsNotchSettings {
        get { self[BindableNotchSettingsKey.self] }
        set { self[BindableNotchSettingsKey.self] = newValue }
    }
}

public struct NotchSettingsKey: EnvironmentKey {
    nonisolated(unsafe) public static let defaultValue: any NotchSettings = MockNotchSettings()
}

public struct BindableNotchSettingsKey: EnvironmentKey {
    nonisolated public static var defaultValue: DefaultsNotchSettings {
        MainActor.assumeIsolated { DefaultsNotchSettings.shared }
    }
}

