//
//  ExternalAppDetector.swift
//  NotchCore
//
//  Finds overlapping third-party apps through LaunchServices.
//

import AppKit
import Foundation

// MARK: - Protocol

@MainActor
public protocol ExternalAppDetecting: AnyObject {
    /// Where the app is, and whether it is running.
    func presence(of app: ExternalAppRef) -> ExternalAppPresence

    /// Drop cached results. Call when a settings surface appears.
    func refresh()
}

extension ExternalAppDetecting {
    /// Pairs a declaration with the current detection result.
    public func resolve(_ declaration: PluginCoexistence) -> ResolvedCoexistence {
        ResolvedCoexistence(declaration: declaration, presence: presence(of: declaration.app))
    }
}

// MARK: - LaunchServices Implementation

/// Neither call prompts the user or needs an entitlement.
///
/// Results are cached because `urlForApplication(withBundleIdentifier:)` queries
/// the LaunchServices database, and settings rows re-render often.
@MainActor
public final class WorkspaceExternalAppDetector: ExternalAppDetecting {
    private var cache: [String: ExternalAppPresence] = [:]

    public init() {}

    public func presence(of app: ExternalAppRef) -> ExternalAppPresence {
        if let cached = cache[app.bundleIdentifier] { return cached }
        let resolved = Self.lookUp(app.bundleIdentifier)
        cache[app.bundleIdentifier] = resolved
        return resolved
    }

    public func refresh() {
        cache.removeAll()
    }

    private static func lookUp(_ bundleIdentifier: String) -> ExternalAppPresence {
        // A running app is installed, so check that first and skip the database.
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        if let url = running.first?.bundleURL {
            return .running(url)
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return .absent
        }
        return .installed(url)
    }
}

// MARK: - Test Double

/// Returns whatever the test sets. Never touches LaunchServices.
@MainActor
public final class StubExternalAppDetector: ExternalAppDetecting {
    public var presences: [String: ExternalAppPresence]
    public private(set) var refreshCount = 0

    public init(presences: [String: ExternalAppPresence] = [:]) {
        self.presences = presences
    }

    public func presence(of app: ExternalAppRef) -> ExternalAppPresence {
        presences[app.bundleIdentifier] ?? .absent
    }

    public func refresh() {
        refreshCount += 1
    }
}
