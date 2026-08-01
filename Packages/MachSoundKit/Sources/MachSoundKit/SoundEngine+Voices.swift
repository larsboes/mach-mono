import Foundation
import MachSoundDSP

/// A visual beat tag attached to the `NoteEvent` that produces it, so the render
/// thread can emit the `BeatEvent` at the exact frame the note sounds.
typealias Beat = (kind: NoteBeatKind, midi: Int32)

extension SoundEngine {

    // MARK: - Enqueue helpers
    @inline(__always)
    func emit(_ event: NoteEvent) { eventQueue.enqueue(event) }

    @inline(__always)
    func frame(_ base: Int64, plus seconds: Double) -> Int64 {
        base + Int64(seconds * sampleRate)
    }

    func hz(midi: Double, cents: Double = 0.0) -> Double {
        440.0 * pow(2.0, (midi - 69.0 + cents / 100.0) / 12.0)
    }

    // MARK: - Voice builders (translate v2 voices into NoteEvents)

    /// Pitch-swept sine kick. EDM kicks set `triggersDuck`.
    func triggerKick(frame f: Int64, freqStart: Double, freqEnd: Double,
                     duration: Double, volume: Double,
                     triggersDuck: Bool = false, beat: Beat? = nil) {
        var e = NoteEvent()
        e.startFrame = f
        e.waveform = .sine
        e.frequency = freqEnd
        e.pitchStart = freqStart
        e.pitchEnd = freqEnd
        e.pitchSweep = duration * 0.5
        e.volume = volume
        e.attack = 0.001
        e.decay = duration
        e.triggersDuck = triggersDuck
        apply(beat, to: &e)
        emit(e)
    }

    /// Filtered one-shot noise (hat / clap / snare / crackle).
    func triggerNoiseHit(frame f: Int64, filter: FilterKind, freq: Double, q: Double,
                         volume: Double, duration: Double, beat: Beat? = nil) {
        var e = NoteEvent()
        e.startFrame = f
        e.useNoise = true
        e.filterKind = filter
        e.cutoff = freq
        e.cutoffEnd = freq
        e.q = q
        e.volume = volume
        e.attack = 0.001
        e.decay = duration
        apply(beat, to: &e)
        emit(e)
    }

    /// Saw bass through a falling lowpass; routed through the sidechain duck bus.
    func triggerBass(frame f: Int64, midi: Double, volume: Double, duration: Double,
                     beat: Beat? = nil) {
        var e = NoteEvent()
        e.startFrame = f
        e.waveform = .saw
        e.frequency = hz(midi: midi)
        e.filterKind = .lowpass
        e.cutoff = 650
        e.cutoffEnd = 220
        e.cutoffSweep = duration
        e.q = 0.707
        e.volume = volume
        e.attack = 0.001
        e.decay = duration
        e.duck = true
        apply(beat, to: &e)
        emit(e)
    }

    /// Detuned saw pad (±7 cents) per chord tone; dry through duck + reverb send.
    func triggerPads(frame f: Int64, midiNotes: [Int], volume: Double,
                     attack: Double, release: Double, cutoff: Double, dur: Double,
                     beatRoot: Int?) {
        for (i, midi) in midiNotes.enumerated() {
            var e = NoteEvent()
            e.startFrame = f
            e.waveform = .saw
            e.frequency = hz(midi: Double(midi))
            e.osc1Cents = -7
            e.osc2Cents = 7
            e.osc2Gain = 1.0
            e.filterKind = .lowpass
            e.cutoff = cutoff
            e.q = 0.707
            e.volume = volume
            e.sustained = true
            e.attack = attack
            e.hold = max(0.0, dur - release - attack)
            e.decay = release
            e.duck = true
            e.reverbSend = 1.0
            if i == 0, let root = beatRoot {
                e.beatKind = .chord
                e.beatMidi = Int32(root)
            }
            emit(e)
        }
    }

    /// Detuned saw lead (±9 cents), bright lowpass, dotted-eighth delay send.
    func triggerLead(frame f: Int64, midi: Double, volume: Double, duration: Double,
                     beat: Beat? = nil) {
        var e = NoteEvent()
        e.startFrame = f
        e.waveform = .saw
        e.frequency = hz(midi: midi)
        e.osc1Cents = -9
        e.osc2Cents = 9
        e.osc2Gain = 1.0
        e.filterKind = .lowpass
        e.cutoff = 2800
        e.q = 0.707
        e.volume = volume
        e.attack = 0.012
        e.decay = duration
        e.delaySend = 1.0
        apply(beat, to: &e)
        emit(e)
    }

    /// One-shot pluck (sine / triangle / square); reverb send optional.
    func triggerPluck(frame f: Int64, midi: Double, volume: Double, duration: Double,
                      waveform: Waveform, sendRev: Bool, beat: Beat? = nil) {
        var e = NoteEvent()
        e.startFrame = f
        e.waveform = waveform
        e.frequency = hz(midi: midi)
        e.volume = volume
        e.attack = 0.01
        e.decay = duration
        e.reverbSend = sendRev ? 1.0 : 0.0
        apply(beat, to: &e)
        emit(e)
    }

    /// Rhodes-ish: sine fundamental (slight detune) + 2nd harmonic at 0.28, lowpass.
    func triggerRhodesNote(frame f: Int64, midi: Double, volume: Double, duration: Double,
                           beat: Beat? = nil) {
        var e = NoteEvent()
        e.startFrame = f
        e.waveform = .sine
        e.frequency = hz(midi: midi)
        e.osc1Cents = Double.random(in: -4...4)
        e.osc2Ratio = 2.0
        e.osc2Gain = 0.28
        e.filterKind = .lowpass
        e.cutoff = 2000
        e.q = 0.707
        e.volume = volume
        e.attack = 0.006
        e.decay = duration
        e.reverbSend = 1.0
        apply(beat, to: &e)
        emit(e)
    }

    /// Strummed Rhodes chord (12 ms per-note offset).
    func triggerRhodesChord(frame f: Int64, midiNotes: [Int], volume: Double, duration: Double,
                            beatRoot: Int?) {
        for (i, midi) in midiNotes.enumerated() {
            let beat: Beat? = (i == 0 && beatRoot != nil) ? (.chord, Int32(beatRoot!)) : nil
            triggerRhodesNote(frame: frame(f, plus: Double(i) * 0.012),
                              midi: Double(midi), volume: volume, duration: duration, beat: beat)
        }
    }

    /// Slow sine sub swell (AHR-linear); dry to master.
    func triggerSubSwell(frame f: Int64, rootMidi: Double, peakVol: Double,
                         attack: Double, hold: Double, release: Double, beat: Beat? = nil) {
        var e = NoteEvent()
        e.startFrame = f
        e.waveform = .sine
        e.frequency = hz(midi: rootMidi)
        e.volume = peakVol
        e.sustained = true
        e.attack = attack
        e.hold = hold
        e.decay = release
        apply(beat, to: &e)
        emit(e)
    }

    @inline(__always)
    private func apply(_ beat: Beat?, to e: inout NoteEvent) {
        if let beat {
            e.beatKind = beat.kind
            e.beatMidi = beat.midi
        }
    }
}
