import Foundation

/// Tonal waveform selector. UInt8-backed so it is trivially copyable across the
/// lock-free event queue.
public enum Waveform: UInt8, Sendable {
    case sine
    case saw
    case square
    case triangle
}

/// Band-limited oscillator using a phase accumulator + PolyBLEP correction.
///
/// Web Audio's `OscillatorNode` emits band-limited saw/square; a naive ramp
/// aliases badly and is a major reason the previous engine sounded cheap. Saw
/// and square are PolyBLEP-corrected here; triangle uses the naive form (its
/// harmonics already roll off as 1/n² so audible aliasing is negligible).
public struct Oscillator {
    public var phase: Double = 0          // [0, 1)
    private var phaseInc: Double = 0
    public let sampleRate: Double

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    public mutating func setFrequency(_ hz: Double) {
        phaseInc = max(0.0, hz) / sampleRate
    }

    /// Reset phase. Use when retriggering a voice to keep transients clean.
    public mutating func reset(phase: Double = 0) {
        self.phase = phase
    }

    @inline(__always)
    private func polyBlep(_ t: Double, _ dt: Double) -> Double {
        if dt <= 0 { return 0 }
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1.0
        } else if t > 1.0 - dt {
            let x = (t - 1.0) / dt
            return x * x + x + x + 1.0
        }
        return 0.0
    }

    public mutating func next(_ waveform: Waveform) -> Double {
        let t = phase
        let dt = phaseInc
        var value: Double

        switch waveform {
        case .sine:
            value = sin(2.0 * .pi * t)
        case .saw:
            value = 2.0 * t - 1.0
            value -= polyBlep(t, dt)
        case .square:
            value = t < 0.5 ? 1.0 : -1.0
            value += polyBlep(t, dt)
            var t2 = t + 0.5
            if t2 >= 1.0 { t2 -= 1.0 }
            value -= polyBlep(t2, dt)
        case .triangle:
            value = 2.0 * abs(2.0 * t - 1.0) - 1.0
        }

        phase += dt
        if phase >= 1.0 { phase -= 1.0 }
        return value
    }
}

/// Fast, allocation-free white noise via xorshift64. Safe to call on the audio
/// render thread.
public struct WhiteNoise {
    private var state: UInt64

    public init(seed: UInt64 = 0x2545F4914F6CDD1D) {
        state = seed != 0 ? seed : 0x9E3779B97F4A7C15
    }

    @inline(__always)
    public mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        // Map top 53 bits to [-1, 1).
        let unit = Double(state >> 11) * (1.0 / 9007199254740992.0)
        return unit * 2.0 - 1.0
    }
}
