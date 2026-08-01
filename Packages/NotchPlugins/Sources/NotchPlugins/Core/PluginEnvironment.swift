//
//  PluginEnvironment.swift
//  machNotch
//
//  Environment keys used by plugins to adapt to the notch layout.
//

import SwiftUI

// MARK: - View Extension for Optional Values

public extension View {
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

// MARK: - Layout Keys (Relocated to NotchUI/UIEnvironment.swift)

// MARK: - XPC Helper Service

struct XPCHelperServiceKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: (any XPCHelperServiceProtocol)? = nil
}

// MARK: - Environment Extension

extension EnvironmentValues {
    public var albumArtNamespace: Namespace.ID? {
        get { self[AlbumArtNamespaceKey.self] }
        set { self[AlbumArtNamespaceKey.self] = newValue }
    }

    public var xpcHelper: (any XPCHelperServiceProtocol)? {
        get { self[XPCHelperServiceKey.self] }
        set { self[XPCHelperServiceKey.self] = newValue }
    }
}
