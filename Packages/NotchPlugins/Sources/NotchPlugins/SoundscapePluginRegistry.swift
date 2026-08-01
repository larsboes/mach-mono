//
//  SoundscapePluginRegistry.swift
//  NotchPluginsWithSoundscape
//
//  Explicit opt-in registry for builds that include MachSoundKit/AudioKit.
//

import NotchPlugins
import NotchSoundscapePlugin

@MainActor
public enum SoundscapePluginRegistry {
    public static func makeBuiltInDescriptors() -> [PluginDescriptor] {
        PluginRegistry.makeBuiltInDescriptors() + [soundscapeDescriptor]
    }

    private static var soundscapeDescriptor: PluginDescriptor {
        PluginDescriptor(
            id: PluginID.soundscape,
            metadata: PluginMetadata(
                name: "Soundscape",
                description: "Adaptive, generative ambient soundscapes",
                icon: "waveform.path",
                category: .media
            ),
            capabilities: [.closedNotchContent, .expandedPanelContent, .settingsContent, .menuBarContent, .positioned],
            closedNotchPosition: .center,
            factory: { SoundscapePlugin() }
        )
    }
}
