import Foundation

struct SoundEngineParameters: Sendable {
    let pace: Double
    let density: Double
    let brightness: Double
    let space: Double
    let pulse: Double
    let texture: Double

    static let defaults = SoundEngineParameters(
        pace: 0.5,
        density: 0.5,
        brightness: 0.5,
        space: 0.5,
        pulse: 0.4,
        texture: 0.4
    )
}
