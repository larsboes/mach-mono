import Foundation

/// Per-sample amplitude envelope covering the two shapes the prototype uses:
///
/// - **Percussive (AD-exp):** linear attack to `peak`, then an exponential decay
///   to a small floor over `decay` seconds — kick, bass, lead, pluck, rhodes.
///   Mirrors Web Audio's `linearRampToValueAtTime` + `exponentialRampToValueAtTime`.
/// - **Sustained (AHR-lin):** linear attack to `peak`, hold, then linear release
///   to zero — pads and the sub swell.
///
/// `isActive` goes false once the envelope completes so the voice pool can
/// reclaim the voice. No allocation; safe on the audio thread.
public struct Envelope {
    private enum Stage { case idle, attack, hold, decay, done }

    private var stage: Stage = .idle
    public private(set) var value: Double = 0

    private var peak: Double = 0
    private var attackInc: Double = 0     // per-sample (linear)
    private var holdRemaining: Int = 0
    private var decayMul: Double = 1      // per-sample multiplier (exponential)
    private var releaseDec: Double = 0    // per-sample subtraction (linear)
    private var exponential: Bool = true

    private static let floor = 0.0008     // matches v2's 0.001-ish target

    public var isActive: Bool { stage != .idle && stage != .done }

    public init() {}

    /// Configure and (re)start the envelope.
    /// - Parameters:
    ///   - sampleRate: audio sample rate.
    ///   - peak: target amplitude after attack.
    ///   - attack: linear attack time in seconds (0 = instant).
    ///   - decay: decay/release time in seconds.
    ///   - hold: sustained-mode hold time in seconds (ignored when not sustained).
    ///   - sustained: true → linear release after hold; false → exponential decay.
    public mutating func trigger(sampleRate: Double,
                                 peak: Double,
                                 attack: Double,
                                 decay: Double,
                                 hold: Double = 0,
                                 sustained: Bool = false) {
        self.peak = max(peak, Self.floor)
        self.exponential = !sustained

        let attackSamples = max(0, Int(attack * sampleRate))
        let decaySamples = max(1, Int(decay * sampleRate))
        holdRemaining = max(0, Int(hold * sampleRate))

        if attackSamples > 0 {
            attackInc = self.peak / Double(attackSamples)
            value = 0
            stage = .attack
        } else {
            value = self.peak
            stage = sustained ? .hold : .decay
        }

        if sustained {
            releaseDec = self.peak / Double(decaySamples)
        } else {
            decayMul = pow(Self.floor / self.peak, 1.0 / Double(decaySamples))
        }
    }

    public mutating func reset() {
        stage = .idle
        value = 0
    }

    @inline(__always)
    public mutating func next() -> Double {
        switch stage {
        case .idle, .done:
            return 0
        case .attack:
            value += attackInc
            if value >= peak {
                value = peak
                stage = exponential ? .decay : .hold
            }
        case .hold:
            if holdRemaining > 0 {
                holdRemaining -= 1
            } else {
                stage = .decay
            }
        case .decay:
            if exponential {
                value *= decayMul
                if value <= Self.floor {
                    value = 0
                    stage = .done
                }
            } else {
                value -= releaseDec
                if value <= 0 {
                    value = 0
                    stage = .done
                }
            }
        }
        return value
    }
}

/// Exponential glide from a start value to a target over a fixed time, then
/// holds the target. Used for the kick pitch sweep and the bass filter sweep,
/// matching Web Audio's `exponentialRampToValueAtTime`.
public struct Glide {
    public private(set) var value: Double = 0
    private var target: Double = 0
    private var mul: Double = 1
    private var samplesRemaining: Int = 0

    public init() {}

    /// Configure a glide. If `samples <= 0` or either endpoint is non-positive,
    /// the value jumps straight to `to`.
    public mutating func start(from: Double, to: Double, samples: Int) {
        target = to
        if samples > 0 && from > 0 && to > 0 {
            value = from
            mul = pow(to / from, 1.0 / Double(samples))
            samplesRemaining = samples
        } else {
            value = to
            samplesRemaining = 0
        }
    }

    /// Hold a constant value with no glide.
    public mutating func hold(_ v: Double) {
        value = v
        target = v
        samplesRemaining = 0
    }

    @inline(__always)
    public mutating func next() -> Double {
        if samplesRemaining > 0 {
            value *= mul
            samplesRemaining -= 1
            if samplesRemaining == 0 { value = target }
        }
        return value
    }
}
