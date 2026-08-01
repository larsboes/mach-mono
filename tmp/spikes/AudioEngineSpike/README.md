# AudioEngineSpike (machSound M0 — throwaway)

Answers the M0 ADR question: **AudioKit (MIT) or hand-rolled AVAudioSourceNode**
for MachSoundKit's synthesis core?

Both targets produce the same sound (ENGINE-SPEC pad voice: Cm triad, 2 saws per
note at ±7 cents, lowpass ~900 Hz, 1.5 s attack + a swept-sine kick, reverb).

```bash
cd tmp/spikes/AudioEngineSpike
swift run HandRolledSpike     # zero deps, raw render block
swift run AudioKitSpike       # resolves AudioKit + SoundpipeAudioKit first
```

## Evaluation checklist (fill into the M0 ADR)

Both targets built and ran cleanly on Xcode 26.5 / Swift 6.3.2 (`swift run
HandRolledSpike`, `swift run AudioKitSpike`, ~12s each, exit 0, no crashes).

| Criterion | HandRolled | AudioKit |
|---|---|---|
| Sounds equivalent to v2 pad/kick? | _pending — Lars to A/B by ear_ | _pending — Lars to A/B by ear_ |
| Code pain (envelope, detune, kick) | ~110 lines: manual saw bank (6 oscillators), one-pole LP, hand-coded attack/release envelope, swept-sine kick — all inside the realtime render block, alloc/lock-free by construction | ~75 lines: `Oscillator`/`Mixer`/`MoogLadder`/`Reverb` cover osc+filter+reverb in ~10 lines, but the envelope/kick-sweep is still hand-rolled via a 10ms main-thread poll loop — AudioKit has no built-in ADSR for a raw `Oscillator` |
| Scheduling story for ENGINE-SPEC 16th-grid | manual sample-accurate clock inside the render block — maps directly onto ENGINE-SPEC's 25ms-lookahead/16th-grid model | spike used a 10ms main-thread poll loop, not sample-accurate; `AppleSequencer`/`CallbackInstrument` exist but weren't exercised — open question for M1 |
| Compile/API drift friction | n/a (0 deps) | **0 fixes needed** — AudioKit 5.6.0 + SoundpipeAudioKit compiled clean against `Oscillator`, `Mixer`, `MoogLadder`, `Reverb`, `Table`, `AUValue`, `AudioEngine` as written, on Swift 6.3.2 |
| Dep weight (resolved checkout + binary delta) | 0 | 17MB resolved source checkouts (AudioKit, AudioKitEX, KissFFT, SoundpipeAudioKit, Tonic); 788MB total `.build` (incl. debug artifacts for both targets) |
| Bazel integration plausibility | trivial (Foundation/AVFoundation only) | open risk, not validated this session — SPM graph includes a C target (KissFFT) and Tonic ships a `.swift.orig` file SwiftPM flags as "unhandled"; rules_swift bridging for mixed Swift/C deps with packaging warnings needs its own check |
| Realtime-safety footguns | 100% ours — render block is alloc/lock-free by hand, enforced by the spike's own constraints | DSP nodes (`Oscillator`/`Mixer`/`MoogLadder`/`Reverb`) run on AudioKit's realtime render graph (handled); envelope/automation timing in the spike runs on the main thread via `Thread.sleep` polling — not realtime-safe and not representative of ENGINE-SPEC's scheduler either way |

**Convolution reverb note:** both spikes used algorithmic reverb (`AVAudioUnitReverb`
.largeHall2 / AudioKit `Reverb`), not the spec's generated-impulse convolution.
SoundpipeAudioKit does compile a `Convolution.swift` node — available if AudioKit is
chosen and convolution proves necessary after the ear A/B. Decision recorded in the
ADR: ship algorithmic reverb for M1, revisit convolution only if the A/B against v2
shows an audible gap.

Verdict: see `docs/decisions/0011-machsound-audio-stack.md`. This folder dies once
M1 scaffolding lands.
