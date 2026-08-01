// HandRolledSpike — machSound M0 spike (throwaway)
// Renders the ENGINE-SPEC "pad" voice (Cm triad, 2 saws per note at ±7 cents,
// one-pole lowpass) plus a swept-sine kick every 2 s, through AVAudioUnitReverb.
// Goal: judge how painful sample-level DSP + AVAudioEngine plumbing feels
// compared to the AudioKitSpike target. Plays ~12 s, then exits.
//
// Spike honesty notes:
// - Reverb here is algorithmic (AVAudioUnitReverb). The spec wants generated-impulse
//   convolution; native options are custom partitioned convolution (vDSP FFT) or
//   accepting algorithmic. That decision is part of the M0 ADR — note your verdict.
// - The render block below is REALTIME code: no allocation, no locks, no ObjC.
//   That constraint is the true cost of the hand-rolled path — feel it.

import AVFoundation
import Foundation

let sampleRate = 48_000.0

// MARK: - Spec values (ENGINE-SPEC §4/§5)
let chordMidis: [Double] = [48, 51, 55]      // Cm
let detunesCents: [Double] = [-7, 7]
let padCutoffHz = 900.0
let padAttack = 1.5
let padReleaseStart = 9.0
let padRelease = 1.5
let kickPeriod = 2.0
let kickFHi = 150.0, kickFLo = 44.0, kickSweep = 0.15, kickDur = 0.3

func hz(midi: Double, cents: Double) -> Double {
    440.0 * pow(2.0, (midi - 69.0 + cents / 100.0) / 12.0)
}

// MARK: - Oscillator state (globals: top-level main.swift, mutable from render block)
var sawPhases: [Double]
var sawIncs: [Double]
do {
    var freqs: [Double] = []
    for m in chordMidis { for c in detunesCents { freqs.append(hz(midi: m, cents: c)) } }
    sawPhases = freqs.map { _ in Double.random(in: 0..<1) }
    sawIncs = freqs.map { $0 / sampleRate }
}
var lpState: Float = 0
let lpCoeff = Float(1 - exp(-2.0 * .pi * padCutoffHz / sampleRate))
var kickPhase = 0.0
var sampleIndex: Int = 0

// MARK: - Engine graph
let engine = AVAudioEngine()
guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
    fatalError("format")
}

let source = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
    let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
    for frame in 0..<Int(frameCount) {
        let t = Double(sampleIndex) / sampleRate

        // Pad: sum saws, normalize, envelope, one-pole lowpass
        var s: Float = 0
        for i in 0..<sawPhases.count {
            sawPhases[i] += sawIncs[i]
            if sawPhases[i] >= 1 { sawPhases[i] -= 1 }
            s += Float(2.0 * sawPhases[i] - 1.0)
        }
        s /= Float(sawPhases.count)
        let env: Float
        if t < padAttack { env = Float(t / padAttack) }
        else if t > padReleaseStart { env = Float(max(0, 1 - (t - padReleaseStart) / padRelease)) }
        else { env = 1 }
        s *= 0.22 * env
        lpState += lpCoeff * (s - lpState)
        var out = lpState

        // Kick: swept sine, exp-ish amp decay, every kickPeriod seconds
        let kt = t.truncatingRemainder(dividingBy: kickPeriod)
        if kt < kickDur {
            let sweep = min(kt / kickSweep, 1.0)
            let f = kickFHi * pow(kickFLo / kickFHi, sweep)
            kickPhase += f / sampleRate
            out += Float(sin(2.0 * .pi * kickPhase)) * Float(exp(-kt * 16.0)) * 0.8
        } else {
            kickPhase = 0
        }

        for buffer in buffers {
            buffer.mData!.assumingMemoryBound(to: Float.self)[frame] = out
        }
        sampleIndex += 1
    }
    return noErr
}

let reverb = AVAudioUnitReverb()
reverb.loadFactoryPreset(.largeHall2)
reverb.wetDryMix = 28

engine.attach(source)
engine.attach(reverb)
engine.connect(source, to: reverb, format: format)
engine.connect(reverb, to: engine.mainMixerNode, format: format)

do {
    try engine.start()
    print("HandRolledSpike: Cm pad (±7c saws, LP \(Int(padCutoffHz)) Hz) + kick, ~12 s…")
    Thread.sleep(forTimeInterval: 12)
    engine.stop()
    print("Done. Judge: envelope feel, detune beating, kick punch, code pain level.")
} catch {
    print("Engine failed to start: \(error)")
    exit(1)
}
