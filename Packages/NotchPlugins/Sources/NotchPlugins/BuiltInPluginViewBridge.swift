//
//  BuiltInPluginViewBridge.swift
//  NotchPlugins
//
//  Keeps app-facing UI integrations behind the NotchPlugins facade.
//

import SwiftUI

public extension PluginManager {
    @ViewBuilder
    func ambientVisualizerView(
        albumColor: Color,
        isPlaying: Bool,
        height: CGFloat,
        useRealAudio: Bool
    ) -> some View {
        if useRealAudio,
            let plugin = plugin(id: PluginID.music, as: MusicPlugin.self)
        {
            MusicAudioReactiveVisualizerView(
                plugin: plugin,
                albumColor: albumColor,
                height: height
            )
        } else {
            AmbientGlowVisualizer(
                albumColor: albumColor,
                isPlaying: isPlaying,
                height: height,
                frequencyBands: []
            )
            .frame(height: height)
        }
    }

    @ViewBuilder
    func faceView(spacing: CGFloat = 8) -> some View {
        NotchMoodView(spacing: spacing)
    }

    @ViewBuilder
    func notesView() -> some View {
        NotesView(manager: services.notesManager)
    }

    @ViewBuilder
    func batteryHeaderContent() -> some View {
        if let batteryPlugin = plugin(id: PluginID.battery, as: BatteryPlugin.self) {
            batteryPlugin.headerContent()
        }
    }
}

private struct MusicAudioReactiveVisualizerView: View {
    let plugin: MusicPlugin
    let albumColor: Color
    let height: CGFloat

    var body: some View {
        AmbientGlowVisualizer(
            albumColor: albumColor,
            isPlaying: true,
            height: height,
            frequencyBands: plugin.frequencyBands
        )
        .frame(height: height)
    }
}
