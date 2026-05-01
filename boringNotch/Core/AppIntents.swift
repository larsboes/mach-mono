import AppIntents

// MARK: - Notch Control

struct OpenNotchIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Notch"
    static var description = IntentDescription("Opens the boringNotch panel.")

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openNotchIntent, object: nil)
        return .result()
    }
}

struct CloseNotchIntent: AppIntent {
    static var title: LocalizedStringResource = "Close Notch"
    static var description = IntentDescription("Closes the boringNotch panel.")

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .closeNotchIntent, object: nil)
        return .result()
    }
}

struct ToggleNotchIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Notch"
    static var description = IntentDescription("Opens the notch if closed, closes it if open.")

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .toggleNotchIntent, object: nil)
        return .result()
    }
}

// MARK: - Music Control

struct ToggleMusicPlaybackIntent: AppIntent {
    static var title: LocalizedStringResource = "Play / Pause Music"
    static var description = IntentDescription("Toggles playback of the current track in boringNotch.")

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .toggleMusicPlaybackIntent, object: nil)
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Track"
    static var description = IntentDescription("Skips to the next track via boringNotch.")

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .nextTrackIntent, object: nil)
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Track"
    static var description = IntentDescription("Goes back to the previous track via boringNotch.")

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .previousTrackIntent, object: nil)
        return .result()
    }
}

// MARK: - Shortcuts Provider

struct BoringNotchShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenNotchIntent(),
            phrases: ["Open \(.applicationName)", "Show \(.applicationName)"],
            shortTitle: "Open Notch",
            systemImageName: "arrow.up.circle"
        )
        AppShortcut(
            intent: CloseNotchIntent(),
            phrases: ["Close \(.applicationName)", "Hide \(.applicationName)"],
            shortTitle: "Close Notch",
            systemImageName: "arrow.down.circle"
        )
        AppShortcut(
            intent: ToggleNotchIntent(),
            phrases: ["Toggle \(.applicationName)"],
            shortTitle: "Toggle Notch",
            systemImageName: "circle.lefthalf.filled"
        )
        AppShortcut(
            intent: ToggleMusicPlaybackIntent(),
            phrases: ["Play pause music in \(.applicationName)", "Toggle music in \(.applicationName)"],
            shortTitle: "Play / Pause",
            systemImageName: "playpause"
        )
        AppShortcut(
            intent: NextTrackIntent(),
            phrases: ["Next track in \(.applicationName)", "Skip song in \(.applicationName)"],
            shortTitle: "Next Track",
            systemImageName: "forward"
        )
        AppShortcut(
            intent: PreviousTrackIntent(),
            phrases: ["Previous track in \(.applicationName)", "Go back in \(.applicationName)"],
            shortTitle: "Previous Track",
            systemImageName: "backward"
        )
    }
}

// MARK: - Notification Names

extension NSNotification.Name {
    static let openNotchIntent = NSNotification.Name("me.theboringteam.boringnotch.open")
    static let closeNotchIntent = NSNotification.Name("me.theboringteam.boringnotch.close")
    static let toggleNotchIntent = NSNotification.Name("me.theboringteam.boringnotch.toggle")
    static let toggleMusicPlaybackIntent = NSNotification.Name("me.theboringteam.boringnotch.music.togglePlayback")
    static let nextTrackIntent = NSNotification.Name("me.theboringteam.boringnotch.music.next")
    static let previousTrackIntent = NSNotification.Name("me.theboringteam.boringnotch.music.previous")
}
