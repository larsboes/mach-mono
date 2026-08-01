//
//  DefaultsNotchSettings+Appearance.swift
//  NotchCore
//
//  Visual effects, webcam/mirror, accent color, and glass effect settings.
//

import Defaults
import NotchSettingsMacro
import SwiftUI

public extension DefaultsNotchSettings {

    // MARK: - Mirror / Webcam

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

    @Setting<String>(key: "selectedWebcamDeviceID", default: "")
    var selectedWebcamDeviceID: String {
        get { Defaults[Self.selectedWebcamDeviceIDKey] }
        set { Defaults[Self.selectedWebcamDeviceIDKey] = newValue }
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

    // MARK: - Visual Effects

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

    // MARK: - Liquid Glass

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

    // MARK: - Accent Color

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
}
