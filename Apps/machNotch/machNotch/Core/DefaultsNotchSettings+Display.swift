//
//  DefaultsNotchSettings+Display.swift
//  boringNotch
//

import Foundation
import Defaults

@MainActor extension DefaultsNotchSettings {
    // MARK: - Appearance Settings
    var alwaysShowTabs: Bool {
        get { Defaults[.alwaysShowTabs] }
        set { Defaults[.alwaysShowTabs] = newValue }
    }
    var showNotHumanFace: Bool {
        get { Defaults[.showNotHumanFace] }
        set { Defaults[.showNotHumanFace] = newValue }
    }
    var lightingEffect: Bool {
        get { Defaults[.lightingEffect] }
        set { Defaults[.lightingEffect] = newValue }
    }
    var liquidGlassEffect: Bool {
        get { Defaults[.liquidGlassEffect] }
        set { Defaults[.liquidGlassEffect] = newValue }
    }
    var liquidGlassStyle: LiquidGlassStyle {
        get { Defaults[.liquidGlassStyle] }
        set { Defaults[.liquidGlassStyle] = newValue }
    }
    var liquidGlassBlurRadius: Double {
        get { Defaults[.liquidGlassBlurRadius] }
        set { Defaults[.liquidGlassBlurRadius] = newValue }
    }
    var backgroundImageURL: URL? {
        get { Defaults[.backgroundImageURL] }
        set { Defaults[.backgroundImageURL] = newValue }
    }
    var enableShadow: Bool {
        get { Defaults[.enableShadow] }
        set { Defaults[.enableShadow] = newValue }
    }
    var cornerRadiusScaling: Bool {
        get { Defaults[.cornerRadiusScaling] }
        set { Defaults[.cornerRadiusScaling] = newValue }
    }
    var settingsIconInNotch: Bool {
        get { Defaults[.settingsIconInNotch] }
        set { Defaults[.settingsIconInNotch] = newValue }
    }
    var menubarIcon: Bool {
        get { Defaults[.menubarIcon] }
        set { Defaults[.menubarIcon] = newValue }
    }

    // MARK: - Display Settings
    var openLastTabByDefault: Bool {
        get { Defaults[.openLastTabByDefault] }
        set { Defaults[.openLastTabByDefault] = newValue }
    }
    var preferredScreenUUID: String? {
        get { Defaults[.preferredScreenUUID] }
        set { Defaults[.preferredScreenUUID] = newValue }
    }
    var showOnAllDisplays: Bool {
        get { Defaults[.showOnAllDisplays] }
        set { Defaults[.showOnAllDisplays] = newValue }
    }
    var automaticallySwitchDisplay: Bool {
        get { Defaults[.automaticallySwitchDisplay] }
        set { Defaults[.automaticallySwitchDisplay] = newValue }
    }
    var hideTitleBar: Bool {
        get { Defaults[.hideTitleBar] }
        set { Defaults[.hideTitleBar] = newValue }
    }
    var extendHoverArea: Bool {
        get { Defaults[.extendHoverArea] }
        set { Defaults[.extendHoverArea] = newValue }
    }
    var showOnLockScreen: Bool {
        get { Defaults[.showOnLockScreen] }
        set { Defaults[.showOnLockScreen] = newValue }
    }
    var hideFromScreenRecording: Bool {
        get { Defaults[.hideFromScreenRecording] }
        set { Defaults[.hideFromScreenRecording] = newValue }
    }
    var hideNonNotchedFromMissionControl: Bool {
        get { Defaults[.hideNonNotchedFromMissionControl] }
        set { Defaults[.hideNonNotchedFromMissionControl] = newValue }
    }
    var useCustomAccentColor: Bool {
        get { Defaults[.useCustomAccentColor] }
        set { Defaults[.useCustomAccentColor] = newValue }
    }
    var customAccentColorData: Data? {
        get { Defaults[.customAccentColorData] }
        set { Defaults[.customAccentColorData] = newValue }
    }
    var releaseName: String { Defaults[.releaseName] }
    var nonNotchHeight: Double {
        get { Defaults[.nonNotchHeight] }
        set { Defaults[.nonNotchHeight] = newValue }
    }
    var nonNotchHeightMode: WindowHeightMode {
        get { Defaults[.nonNotchHeightMode] }
        set { Defaults[.nonNotchHeightMode] = newValue }
    }
    var notchHeight: Double {
        get { Defaults[.notchHeight] }
        set { Defaults[.notchHeight] = newValue }
    }
    var notchHeightMode: WindowHeightMode {
        get { Defaults[.notchHeightMode] }
        set { Defaults[.notchHeightMode] = newValue }
    }
    var inactiveNotchHeight: Double {
        get { Defaults[.inactiveNotchHeight] }
        set { Defaults[.inactiveNotchHeight] = newValue }
    }
    var useInactiveNotchHeight: Bool {
        get { Defaults[.useInactiveNotchHeight] }
        set { Defaults[.useInactiveNotchHeight] = newValue }
    }
}
