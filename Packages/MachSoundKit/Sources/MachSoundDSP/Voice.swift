import Foundation

/// A generic monophonic synth voice driven entirely by a `NoteEvent`.
///
/// One voice type covers every prototype voice (kick, bass, pad tone, lead,
/// pluck, rhodes, noise hit, sub) via two oscillators (or a noise source), an
/// amplitude envelope, an optional pitch glide, and an optional biquad with its
/// own cutoff glide. Pads/chords are played as one voice per chord tone.
///
/// Pre-allocated and reused; `render()` is allocation-free. The owner reads
/// `reverbSend` / `delaySend` / `duck` to route the rendered sample to buses.
public final class Voice {
    private let sampleRate: Double
    private static let controlInterval = 16   // filter coeff recompute period

    private var osc1: Oscillator
    private var osc2: Oscillator
    private var noise = WhiteNoise()
    private var env = Envelope()
    private var pitchGlide = Glide()
    private var cutoffGlide = Glide()
    private var filter: Biquad

    // Per-trigger configuration
    private var waveform: Waveform = .sine
    private var useNoise = false
    private var osc1Mult = 1.0
    private var osc2Mult = 1.0
    private var osc2Gain = 0.0
    private var volume = 0.0
    private var filterKind: FilterKind = .none
    private var filterQ = 0.707
    private var hasPitchSweep = false
    private var hasCutoffSweep = false
    private var controlCounter = 0

    // Routing (read by the owner each sample)
    public private(set) var reverbSend = 0.0
    public private(set) var delaySend = 0.0
    public private(set) var duck = false

    public private(set) var active = false
    /// Samples elapsed since trigger; used for voice-steal priority.
    public private(set) var age = 0

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        osc1 = Oscillator(sampleRate: sampleRate)
        osc2 = Oscillator(sampleRate: sampleRate)
        filter = Biquad(sampleRate: sampleRate)
    }

    public func trigger(_ e: NoteEvent) {
        waveform = e.waveform
        useNoise = e.useNoise
        osc2Gain = e.osc2Gain
        volume = e.volume
        filterKind = e.filterKind
        filterQ = e.q
        reverbSend = e.reverbSend
        delaySend = e.delaySend
        duck = e.duck

        osc1Mult = pow(2.0, e.osc1Cents / 1200.0)
        osc2Mult = e.osc2Ratio * pow(2.0, e.osc2Cents / 1200.0)

        // Pitch
        hasPitchSweep = e.pitchSweep > 0 && e.pitchStart > 0
        if hasPitchSweep {
            pitchGlide.start(from: e.pitchStart, to: e.pitchEnd,
                             samples: Int(e.pitchSweep * sampleRate))
        } else {
            pitchGlide.hold(e.frequency)
        }
        let base = pitchGlide.value
        osc1.reset()
        osc2.reset()
        osc1.setFrequency(base * osc1Mult)
        osc2.setFrequency(base * osc2Mult)

        // Filter + optional cutoff sweep
        hasCutoffSweep = e.cutoffSweep > 0 && filterKind != .none
        if hasCutoffSweep {
            cutoffGlide.start(from: e.cutoff, to: e.cutoffEnd,
                              samples: Int(e.cutoffSweep * sampleRate))
        } else {
            cutoffGlide.hold(e.cutoff)
        }
        if filterKind != .none {
            filter.reset()
            filter.set(kind: filterKind, freq: cutoffGlide.value, q: filterQ)
        }
        controlCounter = 0

        env.trigger(sampleRate: sampleRate, peak: volume == 0 ? 0 : 1.0,
                    attack: e.attack, decay: e.decay, hold: e.hold,
                    sustained: e.sustained)

        age = 0
        active = volume > 0
    }

    public func silence() {
        active = false
        env.reset()
    }

    /// Render one sample. Returns 0 and deactivates when the envelope completes.
    @inline(__always)
    public func render() -> Double {
        guard active else { return 0 }

        let amp = env.next()
        if !env.isActive {
            active = false
            return 0
        }

        let base = hasPitchSweep ? pitchGlide.next() : pitchGlide.value
        if hasPitchSweep {
            osc1.setFrequency(base * osc1Mult)
            osc2.setFrequency(base * osc2Mult)
        }

        var sample: Double
        if useNoise {
            sample = noise.next()
        } else {
            sample = osc1.next(waveform)
            if osc2Gain > 0 {
                sample += osc2.next(waveform) * osc2Gain
            }
        }

        if filterKind != .none {
            if hasCutoffSweep {
                let c = cutoffGlide.next()
                controlCounter += 1
                if controlCounter >= Self.controlInterval {
                    controlCounter = 0
                    filter.set(kind: filterKind, freq: c, q: filterQ)
                }
            }
            sample = filter.process(sample)
        }

        age += 1
        return sample * amp * volume
    }
}
