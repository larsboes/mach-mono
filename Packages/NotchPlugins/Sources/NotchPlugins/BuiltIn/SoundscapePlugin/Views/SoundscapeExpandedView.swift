import MachSoundKit
import NotchUI
import SwiftUI

public struct SoundscapeExpandedView: View {
    @Bindable var plugin: SoundscapePlugin

    private let modes: [SoundMode] = [.edm, .ambient, .lofi, .focus, .relax, .sleep]

    public init(plugin: SoundscapePlugin) {
        self.plugin = plugin
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = Layout(width: proxy.size.width)
            ZStack(alignment: .bottom) {
                fluidScene
                titleBlock(layout: layout)
                controlDock(layout: layout)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .animation(.smooth(duration: 0.24), value: plugin.currentMode)
        .animation(.smooth(duration: 0.2), value: plugin.isPlaying)
    }

    private var fluidScene: some View {
        FluidVisualizerView(
            isPlaying: plugin.isPlaying,
            audioLevel: max(plugin.audioLevel, plugin.isPlaying ? 0.1 : 0.035),
            isBeatActive: plugin.isBeatActive,
            palette: activePalette
        )
        .overlay(sceneShade)
        .background(Color(red: 0.018, green: 0.01, blue: 0.03))
    }

    private var sceneShade: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.48),
                .black.opacity(0.08),
                .black.opacity(0.5),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func titleBlock(layout: Layout) -> some View {
        VStack(spacing: layout.titleSpacing) {
            Text("FLUID SYMPHONY")
                .font(.system(size: layout.titleSize, weight: .light))
                .tracking(layout.titleTracking)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            if !layout.compact {
                Text("the fluid dances to the music")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }

            Text(nowPlaying)
                .font(.system(size: layout.nowPlayingSize, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.purple.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.top, layout.topPadding)
    }

    private var nowPlaying: String {
        plugin.isPlaying ? plugin.currentMode.nowPlayingLabel : "READY"
    }

    private func controlDock(layout: Layout) -> some View {
        VStack(spacing: layout.dockSpacing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: layout.modeSpacing) {
                    playButton

                    ForEach(modes, id: \.self) { mode in
                        modeButton(mode, layout: layout)
                    }
                }
                .padding(.horizontal, 2)
            }

            if layout.compact {
                HStack(spacing: 12) {
                    labeledSlider("VOLUME", value: $plugin.volume) {
                        plugin.updateVolume(plugin.volume)
                    }
                    labeledSlider("INTENSITY", value: $plugin.energy) {
                        plugin.updateEnergy(plugin.energy)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Divider()
                        .frame(height: 28)
                        .overlay(.white.opacity(0.16))

                    labeledSlider("VOLUME", value: $plugin.volume) {
                        plugin.updateVolume(plugin.volume)
                    }
                    .layoutPriority(0)

                    labeledSlider("INTENSITY", value: $plugin.energy) {
                        plugin.updateEnergy(plugin.energy)
                    }
                    .layoutPriority(0)
                }
            }
        }
        .padding(.horizontal, layout.dockHorizontalPadding)
        .padding(.vertical, 10)
        .background(.black.opacity(0.54), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.purple.opacity(0.26), lineWidth: 1)
        )
        .padding(.horizontal, layout.outerHorizontalPadding)
        .padding(.bottom, layout.bottomPadding)
    }

    private var playButton: some View {
        Button {
            plugin.togglePlay()
        } label: {
            Image(systemName: plugin.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.purple.opacity(plugin.isPlaying ? 0.62 : 0.28), in: Circle())
                .overlay(Circle().stroke(.purple.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func modeButton(_ mode: SoundMode, layout: Layout) -> some View {
        Button {
            plugin.updateMode(mode)
        } label: {
            Text(mode.dockTitle)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(plugin.currentMode == mode ? .white : .white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(minWidth: layout.compact ? 50 : 56)
                .padding(.horizontal, layout.compact ? 8 : 10)
                .padding(.vertical, 8)
                .background(modeBackground(for: mode), in: Capsule())
                .overlay(Capsule().stroke(modeStroke(for: mode), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .layoutPriority(1)
    }

    private func modeBackground(for mode: SoundMode) -> Color {
        plugin.currentMode == mode ? .purple.opacity(0.34) : .clear
    }

    private func modeStroke(for mode: SoundMode) -> Color {
        plugin.currentMode == mode ? .purple.opacity(0.95) : .white.opacity(0.14)
    }

    private func labeledSlider(
        _ title: String,
        value: Binding<Double>,
        onChange: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.44))

            Slider(value: value, in: 0...1, onEditingChanged: { _ in onChange() })
                .controlSize(.small)
                .frame(maxWidth: .infinity)
        }
    }

    private var activePalette: [SIMD3<Float>] {
        switch plugin.currentMode {
        case .edm:
            return [.init(0.6, 0.12, 1.0), .init(0.95, 0.24, 0.58), .init(0.16, 0.08, 0.75)]
        case .ambient:
            return [.init(0.16, 0.05, 0.58), .init(0.42, 0.1, 0.85), .init(0.8, 0.18, 0.45)]
        case .lofi:
            return [.init(0.9, 0.36, 0.42), .init(0.68, 0.44, 0.86), .init(0.96, 0.62, 0.32)]
        case .focus:
            return [.init(0.1, 0.48, 0.95), .init(0.18, 0.84, 0.88), .init(0.36, 0.32, 1.0)]
        case .relax:
            return [.init(0.92, 0.44, 0.32), .init(0.32, 0.68, 0.72), .init(0.98, 0.72, 0.4)]
        case .sleep:
            return [.init(0.18, 0.14, 0.52), .init(0.34, 0.22, 0.78), .init(0.52, 0.24, 0.9)]
        }
    }
}

// MARK: - Layout

private struct Layout {
    let width: CGFloat

    var compact: Bool { width < 760 }
    var titleSize: CGFloat { compact ? 18 : 28 }
    var titleTracking: CGFloat { compact ? 5 : 11 }
    var titleSpacing: CGFloat { compact ? 6 : 8 }
    var nowPlayingSize: CGFloat { compact ? 11 : 12 }
    var horizontalPadding: CGFloat { compact ? 16 : 28 }
    var topPadding: CGFloat { compact ? 12 : 24 }
    var modeSpacing: CGFloat { width < 920 ? 6 : 8 }
    var dockSpacing: CGFloat { compact ? 8 : 0 }
    var dockHorizontalPadding: CGFloat { compact ? 10 : 16 }
    var outerHorizontalPadding: CGFloat { compact ? 10 : 28 }
    var bottomPadding: CGFloat { compact ? 10 : 18 }

    init(width: CGFloat) { self.width = width }
}

private extension SoundMode {
    var dockTitle: String {
        switch self {
        case .edm: return "EDM"
        case .ambient: return "AMBIENT"
        case .lofi: return "LO-FI"
        case .focus: return "FOCUS"
        case .relax: return "RELAX"
        case .sleep: return "SLEEP"
        }
    }

    var nowPlayingLabel: String {
        switch self {
        case .edm: return "CLASSICAL × EDM · 126 BPM"
        case .ambient: return "EPIC AMBIENT · 72 BPM"
        case .lofi: return "LO-FI · 78 BPM"
        case .focus: return "FOCUS"
        case .relax: return "RELAX"
        case .sleep: return "SLEEP"
        }
    }
}
