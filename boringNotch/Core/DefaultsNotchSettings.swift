//
//  DefaultsNotchSettings.swift
//  boringNotch
//
//  Production implementation of NotchSettings wrapping Defaults (UserDefaults).
//  Uses @Observable to support SwiftUI bindings via @Bindable.
//
//  NOTE: This file has been split into several extension files to maintain
//  the 300-line hard limit.
//

import Foundation
import Defaults
import Observation

@MainActor
@Observable
final class DefaultsNotchSettings: NotchSettings {
    static let shared = DefaultsNotchSettings()

    // MARK: - General App Settings
    var firstLaunch: Bool {
        get { Defaults[.firstLaunch] }
        set { Defaults[.firstLaunch] = newValue }
    }
    var showWhatsNew: Bool {
        get { Defaults[.showWhatsNew] }
        set { Defaults[.showWhatsNew] = newValue }
    }
    
    var isAIEnabled: Bool {
        get { Defaults[.enableAI] }
        set { Defaults[.enableAI] = newValue }
    }

    // MARK: - One-Time Migrations

    /// Returns `true` if the legacy URL cache still needs to be cleared, and marks it as done.
    func consumeLegacyCacheCleanupFlag() -> Bool {
        if !Defaults[.didClearLegacyURLCacheV1] {
            Defaults[.didClearLegacyURLCacheV1] = true
            return true
        }
        return false
    }
}
