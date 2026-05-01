//
//  PluginEnvironment.swift
//  boringNotch
//
//  Environment keys used by plugins to adapt to the notch layout.
//

import SwiftUI

// MARK: - View Extension for Optional Values

extension View {
    /// Conditionally apply a modifier only when the optional value is non-nil
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, @ViewBuilder transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - Album Art Namespace

struct AlbumArtNamespaceKey: EnvironmentKey {
    // Using optional to avoid creating Namespace outside View.body
    static let defaultValue: Namespace.ID? = nil
}

// MARK: - Layout Keys

struct DisplayClosedNotchHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 32.0
}

struct ContentProgressKey: EnvironmentKey {
    /// Content animation progress (0 = closed, 1 = fully open).
    /// Driven by BoringViewModel.contentRevealProgress with independent curves.
    static let defaultValue: CGFloat = 0.0
}

struct IsNotchClosingKey: EnvironmentKey {
    /// Whether the notch is currently in its closing transition.
    /// ContentRevealModifier uses this for asymmetric close effects.
    static let defaultValue: Bool = false
}

struct CornerRadiusScaleFactorKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

struct CornerRadiusInsetsKey: EnvironmentKey {
    static let defaultValue: CornerRadiusInsets = CornerRadiusInsets(
        opened: (top: 0, bottom: 0),
        closed: (top: 0, bottom: 0)
    )
}

// MARK: - XPC Helper Service

struct XPCHelperServiceKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: (any XPCHelperServiceProtocol)? = nil
}

// MARK: - Environment Extension

extension EnvironmentValues {
    var albumArtNamespace: Namespace.ID? {
        get { self[AlbumArtNamespaceKey.self] }
        set { self[AlbumArtNamespaceKey.self] = newValue }
    }

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

    var xpcHelper: (any XPCHelperServiceProtocol)? {
        get { self[XPCHelperServiceKey.self] }
        set { self[XPCHelperServiceKey.self] = newValue }
    }
}
