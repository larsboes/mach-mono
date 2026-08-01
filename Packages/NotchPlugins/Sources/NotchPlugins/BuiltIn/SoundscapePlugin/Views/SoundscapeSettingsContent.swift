import SwiftUI
import NotchCore
import NotchUI
import MachSoundKit
import NotchServices

public struct SoundscapeSettingsContent: View {
    let plugin: SoundscapePlugin

    public init(plugin: SoundscapePlugin) {
        self.plugin = plugin
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Soundscape Settings")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Namespaced Default settings are loaded and saved automatically during session changes.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding()
    }
}
