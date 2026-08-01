import Foundation

/// Immutable snapshot of control-thread parameters consumed by the scheduler and
/// render thread.
///
/// In Phase 1 this is published atomically (double-buffer / seqlock) from the
/// control thread so neither the scheduler nor the audio render thread ever
/// blocks on a lock to read parameters. Kept as a plain value type so a snapshot
/// is a trivial copy.
public struct ParamSnapshot: Sendable, Equatable {
    public var pace: Double = 0.5
    public var density: Double = 0.5
    public var brightness: Double = 0.5
    public var space: Double = 0.5
    public var pulse: Double = 0.4
    public var texture: Double = 0.4

    public var energy: Double = 0.7
    /// Master gain already squared (`volume * volume`), as the prototype applies it.
    public var masterGain: Double = 0.65 * 0.65

    public static let defaults = ParamSnapshot()

    public init(pace: Double = 0.5,
                density: Double = 0.5,
                brightness: Double = 0.5,
                space: Double = 0.5,
                pulse: Double = 0.4,
                texture: Double = 0.4,
                energy: Double = 0.7,
                masterGain: Double = 0.65 * 0.65) {
        self.pace = pace
        self.density = density
        self.brightness = brightness
        self.space = space
        self.pulse = pulse
        self.texture = texture
        self.energy = energy
        self.masterGain = masterGain
    }
}
