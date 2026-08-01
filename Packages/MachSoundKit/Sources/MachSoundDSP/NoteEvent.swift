import Foundation

/// Visual beat-event classification carried alongside a note so the scheduler
/// can yield `BeatEvent`s at the exact frame a note sounds. UInt8-backed.
public enum NoteBeatKind: UInt8, Sendable {
    case none
    case kick
    case bass
    case chord
    case note
}

/// A fully self-describing note to be synthesized by a generic `Voice`.
///
/// Every field is a scalar or a UInt8-backed enum, so `NoteEvent` is trivially
/// copyable and safe to pass through the cross-thread event queue without any
/// references. Generators set only the fields they need; the rest default to
/// inert values.
///
/// Two oscillators cover all voices:
/// - detuned pair (lead/pad): `osc2Gain = 1`, `osc2Ratio = 1`, ±`osc?Cents`.
/// - harmonic (rhodes): `osc2Ratio = 2`, `osc2Gain = 0.28`.
/// - single osc (kick/bass/pluck): `osc2Gain = 0`.
/// - noise hit: `useNoise = true` (oscillators ignored, biquad shapes the noise).
public struct NoteEvent: Sendable {
    /// Global sample frame at which the note should start.
    public var startFrame: Int64 = 0

    // Source
    public var waveform: Waveform = .sine
    public var useNoise: Bool = false
    public var frequency: Double = 440

    // Oscillator pair
    public var osc1Cents: Double = 0
    public var osc2Cents: Double = 0
    public var osc2Ratio: Double = 1        // frequency multiplier for osc2
    public var osc2Gain: Double = 0         // 0 = osc2 off

    // Amplitude envelope
    public var volume: Double = 0.1
    public var attack: Double = 0.01
    public var decay: Double = 0.5          // decay (percussive) or release (sustained)
    public var hold: Double = 0
    public var sustained: Bool = false      // true = AHR-linear (pad/sub)

    // Filter (+ optional sweep, e.g. bass)
    public var filterKind: FilterKind = .none
    public var cutoff: Double = 20000
    public var cutoffEnd: Double = 20000    // == cutoff when no sweep
    public var cutoffSweep: Double = 0      // seconds (0 = static)
    public var q: Double = 0.707

    // Pitch sweep (e.g. kick): start→end over `pitchSweep` seconds
    public var pitchStart: Double = 0       // 0 = use `frequency`, no sweep
    public var pitchEnd: Double = 0
    public var pitchSweep: Double = 0

    // Routing
    public var reverbSend: Double = 0
    public var delaySend: Double = 0
    public var duck: Bool = false           // route dry signal through the sidechain bus
    public var triggersDuck: Bool = false   // this note starts the sidechain duck (EDM kick)

    // Visual coupling
    public var beatKind: NoteBeatKind = .none
    public var beatMidi: Int32 = -1

    public init() {}
}
