// AudioKitSpike — machSound M0 spike (throwaway)
// Same sound goal as HandRolledSpike: Cm pad (2 saws per note, ±7 cents) through
// a lowpass + reverb, plus a kick. Built with AudioKit (MIT) instead of raw DSP.
//
// EVALUATION NOTE: AudioKit 5 API may have drifted since this was written —
// fixing any compile errors here is *part of the evaluation* (docs quality,
// discoverability, how it feels). Judge on: DX, binary size of the resolved
// build, Bazel-integration plausibility, and whether scheduling envelopes/notes
// per ENGINE-SPEC timing feels natural or fights the framework.

import AudioKit
import SoundpipeAudioKit
import AVFoundation
import Foundation

func hzValue(midi: Double, cents: Double = 0) -> AUValue {
    AUValue(440.0 * pow(2.0, (midi - 69.0 + cents / 100.0) / 12.0))
}

let engine = AudioEngine()

// Pad: 6 detuned saw oscillators (Cm triad × ±7 cents)
var oscillators: [Oscillator] = []
for midi in [48.0, 51.0, 55.0] {
    for cents in [-7.0, 7.0] {
        let osc = Oscillator(
            waveform: Table(.sawtooth),
            frequency: hzValue(midi: midi, cents: cents),
            amplitude: 0.0   // faded in below
        )
        oscillators.append(osc)
    }
}

let padMixer = Mixer(oscillators)
let filter = MoogLadder(padMixer, cutoffFrequency: 900, resonance: 0.05)

// Kick: simple swept oscillator triggered manually (AudioKit has no one-shot
// kick primitive — note how this feels vs the hand-rolled version)
let kickOsc = Oscillator(waveform: Table(.sine), frequency: 150, amplitude: 0)
let mainMix = Mixer(filter, kickOsc)
let reverb = Reverb(mainMix, dryWetMix: 0.28)

engine.output = reverb

do {
    try engine.start()
} catch {
    print("Engine failed to start: \(error)")
    exit(1)
}

oscillators.forEach { $0.start() }
kickOsc.start()

print("AudioKitSpike: Cm pad (±7c saws, MoogLadder) + kick, ~12 s…")

// Crude main-thread automation loop (10 ms ticks) — spike only.
// ENGINE-SPEC needs sample-accurate-ish scheduling; judge whether AudioKit's
// own sequencing (AppleSequencer / CallbackInstrument) would replace this well.
let start = Date()
var lastKick = -2.0
while Date().timeIntervalSince(start) < 12.0 {
    let t = Date().timeIntervalSince(start)

    // pad envelope: 1.5 s linear attack, release from 9 s
    let env: Double
    if t < 1.5 { env = t / 1.5 }
    else if t > 9.0 { env = max(0, 1 - (t - 9.0) / 1.5) }
    else { env = 1 }
    let amp = AUValue(0.07 * env)
    oscillators.forEach { $0.amplitude = amp }

    // kick every 2 s: freq 150→44 over 150 ms, amp decay over 300 ms
    if t - lastKick >= 2.0 { lastKick = t }
    let kt = t - lastKick
    if kt < 0.3 {
        let sweep = min(kt / 0.15, 1.0)
        kickOsc.frequency = AUValue(150.0 * pow(44.0 / 150.0, sweep))
        kickOsc.amplitude = AUValue(0.8 * exp(-kt * 16.0))
    } else {
        kickOsc.amplitude = 0
    }

    Thread.sleep(forTimeInterval: 0.01)
}

engine.stop()
print("Done. Judge: DX vs HandRolledSpike, API drift pain, scheduling story, dep weight.")
