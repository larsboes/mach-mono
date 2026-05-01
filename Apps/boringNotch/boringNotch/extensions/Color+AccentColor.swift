//
//  Color+AccentColor.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-24.
//

import SwiftUI

extension Color {
    @MainActor static func effectiveAccent(from settings: any DisplaySettings) -> Color {
        if settings.useCustomAccentColor,
           let colorData = settings.customAccentColorData,
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            return Color(nsColor: nsColor)
        }
        return .accentColor
    }

    /// Returns a darker version of the accent color suitable for backgrounds
    @MainActor static func effectiveAccentBackground(from settings: any DisplaySettings) -> Color {
        if settings.useCustomAccentColor,
           let colorData = settings.customAccentColorData,
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            return Color(nsColor: nsColor.withSystemEffect(.disabled))
        }
        return Color.effectiveAccent(from: settings).opacity(0.25)
    }

    static func interpolate(
        from: Color,
        to: Color,
        percent t: Double,
        in env: EnvironmentValues
    ) -> Color {
        let t = max(0, min(t, 1))  // clamp

        let c1 = from.resolve(in: env)
        let c2 = to.resolve(in: env)

        let r = c1.red   + (c2.red   - c1.red)   * Float(t)
        let g = c1.green + (c2.green - c1.green) * Float(t)
        let b = c1.blue  + (c2.blue  - c1.blue)  * Float(t)
        let a = c1.opacity + (c2.opacity - c1.opacity) * Float(t)

        return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
}

extension NSColor {
    @MainActor static func effectiveAccent(from settings: any DisplaySettings) -> NSColor {
        if settings.useCustomAccentColor,
           let colorData = settings.customAccentColorData,
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            return nsColor
        }
        return NSColor.controlAccentColor
    }

    /// Approximate equality check to avoid redundant CALayer updates.
    func isClose(to other: NSColor, threshold: CGFloat = 0.02) -> Bool {
        guard let a = usingColorSpace(.deviceRGB), let b = other.usingColorSpace(.deviceRGB) else { return false }
        return abs(a.redComponent - b.redComponent) < threshold
            && abs(a.greenComponent - b.greenComponent) < threshold
            && abs(a.blueComponent - b.blueComponent) < threshold
            && abs(a.alphaComponent - b.alphaComponent) < threshold
    }

    /// Returns a darker version of the accent color as NSColor suitable for backgrounds
    @MainActor static func effectiveAccentBackground(from settings: any DisplaySettings) -> NSColor {
        if settings.useCustomAccentColor,
           let colorData = settings.customAccentColorData,
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            return nsColor.withSystemEffect(.disabled)
        }
        return NSColor.controlAccentColor.withAlphaComponent(0.25)
    }
}
