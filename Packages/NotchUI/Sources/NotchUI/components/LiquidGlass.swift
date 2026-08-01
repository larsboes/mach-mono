//
//  LiquidGlass.swift
//  machNotch
//
//  Created for iOS 26-style liquid glass effect.
//  Refactored to use SwiftGlass library.
//

import SwiftUI

#if canImport(SwiftGlass)
    import SwiftGlass
#endif

// Keep the configuration struct to avoid breaking other code that might reference it,
// even if we don't use all properties anymore.
public struct LiquidGlassConfiguration {
    public var material: NSVisualEffectView.Material = .hudWindow
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    public var tintOpacity: CGFloat = 0.15
    public var borderOpacity: CGFloat = 0.4
    public var borderWidth: CGFloat = 0.5
    public var innerGlowOpacity: CGFloat = 0.1
    public var showSpecularHighlight: Bool = true
    public var depthShadowOpacity: CGFloat = 0.2
    public var ambientLightOpacity: CGFloat = 0.08
    public var edgeGlowOpacity: CGFloat = 0.3
    public var blurRadius: Float = 20.0

    public static let `default` = LiquidGlassConfiguration()

    public static let subtle = LiquidGlassConfiguration(
        tintOpacity: 0.1,
        borderOpacity: 0.25,
        innerGlowOpacity: 0.05,
        depthShadowOpacity: 0.1,
        ambientLightOpacity: 0.04,
        edgeGlowOpacity: 0.15
    )

    public static let vibrant = LiquidGlassConfiguration(
        tintOpacity: 0.2,
        borderOpacity: 0.5,
        borderWidth: 1.0,
        innerGlowOpacity: 0.15,
        depthShadowOpacity: 0.3,
        ambientLightOpacity: 0.12,
        edgeGlowOpacity: 0.4
    )
}

public struct SwiftGlassAdapter: ViewModifier {
    public var isEnabled: Bool
    public var tintColor: Color?

    public init(isEnabled: Bool, tintColor: Color? = nil) {
        self.isEnabled = isEnabled
        self.tintColor = tintColor
    }

    public func body(content: Content) -> some View {
        if isEnabled {
            #if canImport(SwiftGlass)
                content
                    .liquefiedGlass(
                        color: tintColor ?? .clear,
                        blobIntensity: 0.2  // Default intensity, can be parameterized
                    )
            #else
                // Fallback to a simple material if SwiftGlass is not present yet
                content
                    .background(.ultraThinMaterial)
                    .opacity(0.8)
            #endif
        } else {
            content
        }
    }
}

public extension View {
    /// Applies the SwiftGlass effect if the library is available.
    /// Falls back to a simple material otherwise.
    func swiftGlassEffect(isEnabled: Bool = true, tintColor: Color? = nil) -> some View {
        modifier(SwiftGlassAdapter(isEnabled: isEnabled, tintColor: tintColor))
    }
}

import NotchCore

public extension LiquidGlassStyle {
    var configuration: LiquidGlassConfiguration {
        switch self {
        case .default: return .default
        case .subtle: return .subtle
        case .vibrant: return .vibrant
        }
    }
}
