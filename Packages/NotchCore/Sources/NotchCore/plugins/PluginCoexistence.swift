//
//  PluginCoexistence.swift
//  NotchCore
//
//  Declares that a third-party macOS app covers the same ground as a built-in
//  plugin, so machNotch can step aside instead of competing with it.
//

import Foundation

// MARK: - External App Reference

/// A macOS app outside mach-mono that overlaps a built-in plugin.
public struct ExternalAppRef: Sendable, Hashable, Identifiable {
    public var id: String { bundleIdentifier }

    /// Name shown to the user.
    public let name: String

    /// Bundle identifier used for detection. Must match the app's code signature.
    public let bundleIdentifier: String

    /// Where to send a user who wants to install it.
    public let homepage: URL?

    public init(name: String, bundleIdentifier: String, homepage: URL? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.homepage = homepage
    }
}

// MARK: - Presence

/// Whether an external app is on this Mac, and whether it is running.
public enum ExternalAppPresence: Sendable, Hashable {
    case absent
    case installed(URL)
    case running(URL)

    public var isInstalled: Bool {
        switch self {
        case .absent: return false
        case .installed, .running: return true
        }
    }

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    public var bundleURL: URL? {
        switch self {
        case .absent: return nil
        case .installed(let url), .running(let url): return url
        }
    }
}

// MARK: - Policy

/// What machNotch does when the overlapping app is present.
///
/// Neither case ever changes plugin state on its own. A user who deliberately
/// runs both apps must not have a plugin switched off behind their back.
public enum CoexistencePolicy: Sendable, Hashable {
    /// Show that the overlap exists. Change nothing.
    case inform

    /// Show the overlap and offer a one-click way to turn the plugin off.
    case recommendDisable
}

// MARK: - Declaration

/// A descriptor's claim that some other app already does this job.
public struct PluginCoexistence: Sendable, Hashable {
    public let app: ExternalAppRef

    /// The overlapping feature, named the way the other app names it.
    /// Shown to the user, so keep it short and concrete.
    public let overlap: String

    public let policy: CoexistencePolicy

    public init(app: ExternalAppRef, overlap: String, policy: CoexistencePolicy = .recommendDisable) {
        self.app = app
        self.overlap = overlap
        self.policy = policy
    }
}

// MARK: - Resolved State

/// A declaration plus the detection result, ready for a settings row to render.
public struct ResolvedCoexistence: Sendable, Hashable {
    public let declaration: PluginCoexistence
    public let presence: ExternalAppPresence

    public init(declaration: PluginCoexistence, presence: ExternalAppPresence) {
        self.declaration = declaration
        self.presence = presence
    }

    public var app: ExternalAppRef { declaration.app }
    public var overlap: String { declaration.overlap }
    public var policy: CoexistencePolicy { declaration.policy }

    /// True when the other app is installed, so this plugin duplicates it.
    public var isRedundant: Bool { presence.isInstalled }

    /// True when the plugin may be switched off with one click.
    public var offersDisable: Bool { isRedundant && policy == .recommendDisable }

    /// One line for the settings row. Nil when there is nothing to say.
    public var summaryText: String? {
        guard isRedundant else { return nil }
        return "\(app.name) already provides \(overlap)."
    }
}

// MARK: - Known Apps

public enum KnownExternalApp {
    /// Vorssaint, a menu bar toolkit that overlaps several machNotch plugins.
    ///
    /// The bundle identifier is taken from the shipped binary's code signature
    /// (`Identifier=com.vorssaint.utils`), which also matches the Homebrew
    /// cask's `uninstall quit:` key in Homebrew/homebrew-cask `Casks/v/vorssaint.rb`.
    public static let vorssaint = ExternalAppRef(
        name: "Vorssaint",
        bundleIdentifier: "com.vorssaint.utils",
        homepage: URL(string: "https://vorssaint.com")
    )
}
