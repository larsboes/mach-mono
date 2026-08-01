//
//  MusicPlugin+Views.swift
//  machNotch
//
//  SwiftUI view builders for MusicPlugin.
//

import SwiftUI

extension MusicPlugin {
    @ViewBuilder
    public func closedNotchContent() -> some View {
        if isEnabled, state.isActive, let service = musicService {
            MusicLiveActivity(service: service, frequencyBands: frequencyBands)
        }
    }

    @ViewBuilder
    public func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            MusicExpandedViewWrapper(plugin: self)
        }
    }

    @ViewBuilder
    public func settingsContent() -> some View {
        Media()
    }

    @ViewBuilder
    public func menuBarView() -> some View {
        if isEnabled, state.isActive, let info = nowPlaying {
            Section(info.track.title) {
                Text(info.track.artist)
            }
            Button(info.isPlaying ? "Pause" : "Play") {
                Task { [weak self] in await self?.togglePlayPause() }
            }
            Button("Next Track") {
                Task { [weak self] in await self?.next() }
            }
        }
    }
}

// MARK: - Expanded View Wrapper

struct MusicExpandedViewWrapper: View {
    let plugin: MusicPlugin
    @Environment(\.albumArtNamespace) var namespace: Namespace.ID?

    var body: some View {
        PluginMusicPlayerView(plugin: plugin, albumArtNamespace: namespace)
    }
}
