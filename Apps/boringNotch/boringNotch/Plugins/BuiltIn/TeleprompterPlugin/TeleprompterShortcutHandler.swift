//
//  TeleprompterShortcutHandler.swift
//  boringNotch
//
//  Standalone keyboard shortcut handler for the Teleprompter plugin.
//  All shortcuts are user-configurable — no default key combos.
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let teleprompterPlayPause = Self("teleprompterPlayPause")
    static let teleprompterSpeedUp = Self("teleprompterSpeedUp")
    static let teleprompterSpeedDown = Self("teleprompterSpeedDown")
    static let teleprompterReset = Self("teleprompterReset")
    static let teleprompterGoHome = Self("teleprompterGoHome")
}

@MainActor
final class TeleprompterShortcutHandler {
    private unowned let state: TeleprompterState

    private static let allShortcuts: [KeyboardShortcuts.Name] = [
        .teleprompterPlayPause,
        .teleprompterSpeedUp,
        .teleprompterSpeedDown,
        .teleprompterReset,
        .teleprompterGoHome
    ]

    init(state: TeleprompterState) {
        self.state = state
    }

    // MARK: - Registration

    func register() {
        KeyboardShortcuts.onKeyDown(for: .teleprompterPlayPause) { [weak self] in
            guard let self, !self.state.text.isEmpty else { return }
            self.state.toggleScrolling()
        }

        KeyboardShortcuts.onKeyDown(for: .teleprompterSpeedUp) { [weak self] in
            guard let self, !self.state.text.isEmpty else { return }
            self.state.increaseSpeed()
        }

        KeyboardShortcuts.onKeyDown(for: .teleprompterSpeedDown) { [weak self] in
            guard let self, !self.state.text.isEmpty else { return }
            self.state.decreaseSpeed()
        }

        KeyboardShortcuts.onKeyDown(for: .teleprompterReset) { [weak self] in
            guard let self, !self.state.text.isEmpty else { return }
            self.state.reset()
        }

        KeyboardShortcuts.onKeyDown(for: .teleprompterGoHome) { [weak self] in
            guard let self, !self.state.text.isEmpty else { return }
            self.state.goHome()
        }
    }

    func unregister() {
        for name in Self.allShortcuts {
            KeyboardShortcuts.disable(name)
        }
    }
}
