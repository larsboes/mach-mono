# 0011 — machSound Audio Stack: AudioKit over Hand-Rolled AVAudioEngine

- Status: Accepted
- Date: 2026-06-10

## Context

`Plans/PLAN-machSound.md` (machSound, M0) requires picking the synthesis foundation for
`Packages/MachSoundKit` before M1 (the native audio engine) can start: AudioKit
(MIT) or hand-rolled `AVAudioSourceNode` + vDSP. The plan's stated worry was
API drift/maturity risk in AudioKit 5 ("AudioKit 5 API may have drifted since
this was written — fixing any compile errors here is part of the evaluation").

`tmp/spikes/AudioEngineSpike` implemented the same target sound (ENGINE-SPEC
§4/§5 pad voice: Cm triad, 2 detuned saws per note at ±7 cents, ~900 Hz
lowpass, 1.5s attack, plus a swept-sine kick, through reverb) twice — once
hand-rolled, once with AudioKit + SoundpipeAudioKit — and both were built and
run on Xcode 26.5 / Swift 6.3.2. Full eval table:
`tmp/spikes/AudioEngineSpike/README.md`.

Findings:

- **AudioKit 5.6.0 + SoundpipeAudioKit compiled clean on the first try** — 0
  fixes needed. The drift risk the plan flagged did not materialize.
- AudioKit's `Oscillator`/`Mixer`/`MoogLadder`/`Reverb`/`Convolution` cover the
  bulk of ENGINE-SPEC's synthesis primitives in a fraction of the code
  (~75 lines vs ~110 for the equivalent hand-rolled render block).
- Neither AudioKit nor a hand-rolled `AVAudioSourceNode` gives ENGINE-SPEC's
  25ms-lookahead/16th-grid scheduler for free — both spikes used ad-hoc timing
  (manual sample clock vs a 10ms main-thread poll loop). M1's scheduler is
  custom work either way; AudioKit's `AppleSequencer`/`CallbackInstrument`
  remain unexplored options to revisit during M1.
- Dependency cost: 17MB resolved source checkouts (AudioKit, AudioKitEX,
  KissFFT, SoundpipeAudioKit, Tonic), 788MB total `.build` for the spike
  (debug artifacts for both targets — not representative of a release binary
  delta).
- **Open risk, not resolved by this spike:** Bazel/`rules_swift` integration.
  AudioKit's SPM graph includes a C target (KissFFT) and Tonic ships a
  `.swift.orig` file SwiftPM flags as "unhandled" — mixed Swift/C SPM deps
  under `rules_swift` need their own validation before/during M1 scaffolding.
- **Reverb:** ENGINE-SPEC wants generated-impulse convolution; both spikes used
  algorithmic reverb. SoundpipeAudioKit ships a `Convolution` node, so this is
  available if AudioKit is chosen and the ear A/B (below) shows a gap.
- **Sound parity ("sounds equivalent to v2")** is an ear-judgment item left for
  Lars — both spikes ran to completion (~12s, exit 0) but were not A/B'd by ear
  in this session.

## Decision

**Adopt AudioKit (MIT) + SoundpipeAudioKit as MachSoundKit's synthesis
foundation.** Hand-rolled `AVAudioSourceNode`/vDSP remains the documented
fallback (per `Plans/PLAN-machSound.md` §1) only if the two open risks below resolve
unfavorably.

Rationale: the plan's primary worry (API drift) is resolved — AudioKit
compiled clean against current APIs. The DX win (far less code for oscillators,
filters, reverb, convolution) is real and matches the plan's expectation that
AudioKit "could collapse M1 by 60–70%". The scheduling gap (ENGINE-SPEC's
lookahead model) is custom work under either choice, so it is not a
differentiator.

## Consequences

Accepted:

- M1 scaffolding (`Packages/MachSoundKit`) adds AudioKit + SoundpipeAudioKit as
  SPM dependencies (MIT, compatible with ADR 0003's license policy).
- M1's scheduler (lookahead loop, 16th-grid, beat-event emission) is custom
  code regardless — AudioKit does not replace ENGINE-SPEC's timing model.
- Reverb ships algorithmic in M1; convolution (via SoundpipeAudioKit's
  `Convolution` node) is a follow-up only if the v2 ear A/B shows an audible
  gap.

Follow-ups (must land before/during M1, not blockers to this decision):

1. **Bazel/rules_swift validation** — confirm `Packages/MachSoundKit` with
   AudioKit + SoundpipeAudioKit (incl. the KissFFT C target and Tonic's
   packaging warning) integrates cleanly with the repo's Bazel graph (ADR
   0004/0007/0009). If this fails, fall back to hand-rolled per the plan's
   contingency.
2. **Ear parity A/B** — Lars to A/B both spike outputs against
   `fluid-symphony-v2.html` per the parity checklist in `ENGINE-SPEC.md`.
   `tmp/spikes/AudioEngineSpike` stays in place until this is done.

## Related

- `Plans/PLAN-machSound.md` §1 (Costs of Native-First), §2 (Engine Spec), M0/M1
- `tmp/ENGINE-SPEC.md` — Parity Checklist (M1 gate)
- `tmp/spikes/AudioEngineSpike/README.md` — full eval table
- ADR 0003 — license policy (AudioKit MIT permitted)
