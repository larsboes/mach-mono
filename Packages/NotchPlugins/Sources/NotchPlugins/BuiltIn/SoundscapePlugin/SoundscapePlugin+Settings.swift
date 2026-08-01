//
//  SoundscapePlugin+Settings.swift
//  NotchPlugins
//
//  Session defaults for the Soundscape plugin.
//

import MachSoundKit
import NotchCore

@MainActor
extension SoundscapePlugin {
    func loadSettings() {
        guard let settings else { return }

        isPlaying = false
        currentMode = loadedMode()
        volume = settings.get("volume", default: 0.65)
        energy = settings.get("energy", default: 0.7)
        isAdaptive = settings.get("isAdaptive", default: false)

        pace = settings.get("pace", default: 0.5)
        density = settings.get("density", default: 0.5)
        brightness = settings.get("brightness", default: 0.5)
        space = settings.get("space", default: 0.5)
        pulse = settings.get("pulse", default: 0.4)
        texture = settings.get("texture", default: 0.4)
    }

    private func loadedMode() -> SoundMode {
        let rawMode: String = settings?.get("mode", default: SoundMode.edm.rawValue) ?? SoundMode.edm.rawValue
        return SoundMode(rawValue: rawMode) ?? .edm
    }
}
