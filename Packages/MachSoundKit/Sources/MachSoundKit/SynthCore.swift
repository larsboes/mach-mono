import Foundation
import os
import MachSoundDSP

/// Continuous control values published from the scheduler/control thread to the
/// render thread once per block. All POD.
struct SynthControls: Sendable {
    var masterGain: Double = 0.65 * 0.65
    var reverbReturnGain: Double = 0.22
    var reverbRoom: Double = 0.7
    var reverbDamping: Double = 0.5
    var delaySamples: Int = 12000
    var delayFeedback: Double = 0.32
    var vinylGain: Double = 0.0
    var textureGain: Double = 0.0
    var textureCutoff: Double = 900.0
}

/// Real-time synthesis core: owns the voice pool, the continuous noise beds, the
/// effect buses (sidechain duck, dotted-eighth delay, Freeverb, master
/// compressor), and the master sample clock. Filled by the `AVAudioSourceNode`
/// render block in `SynthCore+Render.swift`.
///
/// `@unchecked Sendable`: thread-safety is managed manually — the render thread
/// is the sole consumer of voices/beds/effects; controls cross threads via a
/// short `os_unfair_lock`, and `currentFrame` is a 64-bit aligned scalar read by
/// the scheduler.
final class SynthCore: @unchecked Sendable {
    let sampleRate: Double
    let eventQueue: EventQueue
    let beatSink: BeatSink

    // Voices + beds + effects (render-thread only).
    let voices: VoicePool
    private let reverb: Reverb
    private let delay: DelayLine
    private let compressor: Compressor

    private var vinylNoise = WhiteNoise(seed: 0x1234_5678_9ABC_DEF0)
    private var vinylLP: Biquad
    private var vinylHP: Biquad
    private var textureNoise = WhiteNoise(seed: 0x0FED_CBA9_8765_4321)
    private var textureLP: Biquad

    // Pending events awaiting their frame (render-thread only).
    var pending: [NoteEvent]
    var pendingCount = 0

    /// Master sample clock; incremented per rendered frame. Read by the scheduler.
    private(set) var currentFrame: Int64 = 0

    // Smoothed continuous params (render-thread only).
    private(set) var smMasterGain = 0.0
    private(set) var smReverbReturn = 0.0
    private(set) var smVinylGain = 0.0
    private(set) var smTextureGain = 0.0
    private(set) var lastTextureCutoff = 0.0
    let smoothCoef: Double

    // Sidechain duck envelope (render-thread only).
    private(set) var duckValue = 1.0
    private var duckRampInc = 0.0
    private var duckRampRemaining = 0

    // Audio level (RMS) for visuals.
    private var levelAccum = 0.0
    private let levelLock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
    private var levelValue: Float = 0

    // Published controls.
    private var controls = SynthControls()
    private let controlsLock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)

    init(sampleRate: Double, voiceCount: Int = 64, eventQueue: EventQueue, beatSink: BeatSink) {
        self.sampleRate = sampleRate
        self.eventQueue = eventQueue
        self.beatSink = beatSink
        voices = VoicePool(sampleRate: sampleRate, count: voiceCount)
        reverb = Reverb(sampleRate: sampleRate)
        delay = DelayLine(maxDelaySeconds: 2.0, sampleRate: sampleRate)
        compressor = Compressor(sampleRate: sampleRate)

        vinylLP = Biquad(sampleRate: sampleRate)
        vinylHP = Biquad(sampleRate: sampleRate)
        textureLP = Biquad(sampleRate: sampleRate)
        vinylLP.setLowpass(freq: 4200, q: 0.707)
        vinylHP.setHighpass(freq: 600, q: 0.707)
        textureLP.setLowpass(freq: 900, q: 0.707)

        pending = [NoteEvent](repeating: NoteEvent(), count: 1024)
        smoothCoef = 1.0 - exp(-1.0 / (0.02 * sampleRate))   // ~20 ms

        controlsLock.initialize(to: os_unfair_lock())
        levelLock.initialize(to: os_unfair_lock())
    }

    deinit {
        controlsLock.deinitialize(count: 1); controlsLock.deallocate()
        levelLock.deinitialize(count: 1); levelLock.deallocate()
    }

    // MARK: - Control plane

    func updateControls(_ c: SynthControls) {
        os_unfair_lock_lock(controlsLock)
        controls = c
        os_unfair_lock_unlock(controlsLock)
    }

    func snapshotControls() -> SynthControls {
        os_unfair_lock_lock(controlsLock)
        let c = controls
        os_unfair_lock_unlock(controlsLock)
        return c
    }

    var audioLevel: Float {
        os_unfair_lock_lock(levelLock)
        let v = levelValue
        os_unfair_lock_unlock(levelLock)
        return v
    }

    func publishLevel(_ v: Float) {
        os_unfair_lock_lock(levelLock)
        levelValue = v
        os_unfair_lock_unlock(levelLock)
    }

    // MARK: - Lifecycle

    /// Reset all DSP state. Call before starting playback.
    func reset() {
        voices.silenceAll()
        reverb.reset()
        delay.reset()
        compressor.reset()
        vinylLP.reset(); vinylHP.reset(); textureLP.reset()
        pendingCount = 0
        currentFrame = 0
        duckValue = 1.0
        duckRampRemaining = 0
        let c = snapshotControls()
        smMasterGain = c.masterGain
        smReverbReturn = c.reverbReturnGain
        smVinylGain = c.vinylGain
        smTextureGain = c.textureGain
        lastTextureCutoff = c.textureCutoff
    }

    // MARK: - Render-thread helpers (used by SynthCore+Render)

    @inline(__always)
    func advanceFrame() { currentFrame &+= 1 }

    @inline(__always)
    func startDuck() {
        // Ramp 0.22 → 1.0 over 300 ms (matches v2 sidechain).
        duckValue = 0.22
        let samples = max(1, Int(0.30 * sampleRate))
        duckRampInc = (1.0 - 0.22) / Double(samples)
        duckRampRemaining = samples
    }

    @inline(__always)
    func nextDuck() -> Double {
        if duckRampRemaining > 0 {
            duckValue += duckRampInc
            duckRampRemaining -= 1
            if duckRampRemaining == 0 { duckValue = 1.0 }
        }
        return duckValue
    }

    @inline(__always)
    func nextVinyl() -> Double {
        let n = vinylNoise.next()
        return vinylHP.process(vinylLP.process(n))
    }

    @inline(__always)
    func nextTexture() -> Double {
        textureLP.process(textureNoise.next())
    }

    @inline(__always)
    func reverbProcess(_ x: Double) -> Double { reverb.process(x) }

    @inline(__always)
    func delayProcess(_ x: Double) -> Double { delay.process(x) }

    @inline(__always)
    func compress(_ x: Double) -> Double { compressor.process(x) }

    func applyBlockControls(_ c: SynthControls) {
        reverb.roomSize = c.reverbRoom
        reverb.damping = c.reverbDamping
        delay.delaySamples = c.delaySamples
        delay.feedback = c.delayFeedback
        if abs(c.textureCutoff - lastTextureCutoff) > 1.0 {
            textureLP.setLowpass(freq: c.textureCutoff, q: 0.707)
            lastTextureCutoff = c.textureCutoff
        }
    }

    @inline(__always)
    func smoothGains(toward c: SynthControls) {
        smMasterGain += smoothCoef * (c.masterGain - smMasterGain)
        smReverbReturn += smoothCoef * (c.reverbReturnGain - smReverbReturn)
        smVinylGain += smoothCoef * (c.vinylGain - smVinylGain)
        smTextureGain += smoothCoef * (c.textureGain - smTextureGain)
    }

    func accumulateLevel(_ blockSum: Double, frames: Int) {
        guard frames > 0 else { return }
        let rms = (blockSum / Double(frames)).squareRoot()
        levelAccum = 0.85 * levelAccum + 0.15 * rms
        publishLevel(Float(min(1.0, levelAccum * 3.0)))
    }
}
