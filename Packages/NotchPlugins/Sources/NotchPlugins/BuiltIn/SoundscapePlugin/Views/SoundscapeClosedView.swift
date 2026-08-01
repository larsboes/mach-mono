import SwiftUI
import NotchCore
import NotchUI
import MachSoundKit
import NotchServices

public struct SoundscapeClosedView: View {
    let plugin: SoundscapePlugin

    public init(plugin: SoundscapePlugin) {
        self.plugin = plugin
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path")
                .font(.system(size: 14))
                .foregroundStyle(plugin.isPlaying ? Color.accentColor : Color.white.opacity(0.6))
                .scaleEffect(plugin.isBeatActive ? 1.3 : 1.0)
                .animation(.spring(response: 0.15, dampingFraction: 0.5), value: plugin.isBeatActive)

            if plugin.isPlaying {
                Text(plugin.currentMode.rawValue.capitalized)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
