//
//  SoundscapePrototypeDefaults.swift
//  NotchPlugins
//
//  Native defaults mirrored from tmp/fluid-symphony-v2.html.
//

import MachSoundKit

struct SoundscapePrototypeDefaults {
    let pace: Double
    let density: Double
    let brightness: Double
    let space: Double
    let pulse: Double
    let texture: Double
}

extension SoundMode {
    var prototypeSceneDefaults: SoundscapePrototypeDefaults? {
        switch self {
        case .focus:
            SoundscapePrototypeDefaults(
                pace: 0.55,
                density: 0.5,
                brightness: 0.6,
                space: 0.35,
                pulse: 0.55,
                texture: 0.35
            )
        case .relax:
            SoundscapePrototypeDefaults(
                pace: 0.4,
                density: 0.35,
                brightness: 0.42,
                space: 0.6,
                pulse: 0.3,
                texture: 0.45
            )
        case .sleep:
            SoundscapePrototypeDefaults(
                pace: 0.22,
                density: 0.15,
                brightness: 0.2,
                space: 0.85,
                pulse: 0.15,
                texture: 0.55
            )
        case .edm, .ambient, .lofi:
            nil
        }
    }
}
