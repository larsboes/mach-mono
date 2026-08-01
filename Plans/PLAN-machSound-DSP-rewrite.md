---
id: machsound-dsp-rewrite
status: in_progress
owner: larsboes
source_of_truth: false
parent_plan: Plans/PLAN-machSound.md
triggers: "PLAN-machSound.md M3.5 decision gate — custom AVAudioSourceNode path"
reference_spec: tmp/ENGINE-SPEC.md
executable_reference: website/public/fluid-symphony.html
decision: "Option A — sample-accurate custom DSP voice engine behind the existing SoundEngine public API"
last_updated: 2026-06-14
---

# machSound — Sample-Accurate DSP Engine Rewrite (M3.5a)

**Goal:** Make the native Soundscape sound like the Fluid Symphony v2 prototype,
not merely share its structure. Replace the AudioKit node-graph + 25 ms polling
internals of `Packages/MachSoundKit` with a sample-accurate, polyphonic, custom
DSP engine rendered through a single `AVAudioSourceNode`, while keeping the
`SoundEngine` public API byte-for-byte identical so `SoundscapePlugin` is untouched.

This is the committed resolution of the **M3.5 decision gate** in
`Plans/PLAN-machSound.md`. That file remains the source of truth for the overall
machSound roadmap; this file owns the engine-internals rewrite only.

> **Reference note:** the executable reference prototype now lives at
> `website/public/fluid-symphony.html` (published as a static asset). It is the
> v2 gold-standard for every A/B comparison.

---

## 0. Completion status (2026-06-14)

The engine rewrite is **structurally complete and shipping** through `task run`.
Phases 0–3 are done; Phase 4 (reconcile + tune by ear) is the remaining work.

| Phase | Scope | Status |
|---|---|---|
| 0 | DSP primitives + unit tests | ✅ Done |
| 1 | Render path + full voice mapping | ✅ Done |
| 2 | Effects + gain staging (duck/delay/reverb/comp) | ✅ Done |
| 3 | Sample-accurate scheduling (no `asyncAfter`) | ✅ Done (landed early, in Phase 1) |
| 4 | Reconcile to spec + tune by ear | ⏳ In progress — see §7 |

**Deviations from this plan as written (all intentional, recorded here):**

1. **DSP primitives live in a separate Swift module `MachSoundDSP`**, not a `DSP/`
   subfolder of `MachSoundKit`. Forced by a type-name collision with AudioKit
   (`Oscillator`, `Reverb`, etc.) during migration; kept after AudioKit removal
   because the clean module boundary is good hygiene and keeps the primitives
   independently testable (`DSPPrimitivesTests`).
2. **AudioKit + SoundpipeAudioKit were fully removed** from `Package.swift` and
   `BUILD.bazel`. The plan called this an *optional follow-up*; it was done now
   because the new synth uses only `AVFoundation` and the lingering transitive
   `AudioKitEX` symbols broke the Soundscape app link. `task run:lite` parity is
   moot — the rich build is now AudioKit-free too.
3. **Sample-accurate scheduling shipped in Phase 1, not Phase 3.** No `asyncAfter`
   polling scheduler was ever committed in the rewrite; the lookahead scheduler is
   frame-based from the start (`SoundEngine+Controls.swift` `schedulerTick`).
4. **`SoundEngine+Scheduler.swift` is named `SoundEngine+Controls.swift`** (it owns
   the param API + lookahead scheduler + control-plane snapshot together).
5. **New files not in the original file plan:** `BeatSink.swift` (render-thread →
   main-thread SPSC ring for visual beats, emitted at the exact render frame),
   `SynthCore+Render.swift` (render loop split out for the ≤300-line rule),
   `SynthControls` struct (supersedes most of `ParamSnapshot`'s role; published via
   a short `os_unfair_lock`), and `OfflineRenderTests.swift` (offline render
   diagnostic harness).
6. **Retired files deleted:** `SoundEngine+Setup.swift`, `SoundEngine+Automation.swift`,
   `LeadPluckVoiceHelpers.swift`, `RhodesVoiceHelper.swift` (constants migrated first).

---

## 1. Diagnosis — why the current native engine sounds bad

The prototype is Web Audio: **one fresh node per note**, each with envelopes
scheduled at an exact sample time. The native port uses a structurally different
and wrong model. Ranked by audible impact:

1. **Nothing is sample-accurate.** Steps fire via `DispatchQueue.asyncAfter` on
   wall-clock `Date()`, then mutate AudioKit node params immediately on a
   background thread (`SoundEngine+Automation.swift` `schedulerTick` →
   `asyncAfter` → `executeStep`). Millisecond-plus jitter smears the groove;
   Lo-fi nests a *second* `asyncAfter` for swing.
2. **Kick / bass / sub are monophonic oscillators polled at 25 ms (40 Hz).**
   `updateAutomations` recomputes their pitch sweep and amplitude decay as a
   stair-stepped envelope written directly to `.amplitude`/`.frequency`
   (`SoundEngine+Automation.swift` §1–§2). Result: clicky, weak, imprecise
   low end; overlapping hits steal the single voice → the "samey" feel.
3. **`MoogLadder` everywhere (the "too dark" complaint).** Bass, pad, and lead
   run through a colored, resonant 4-pole (24 dB/oct) filter where the prototype
   used gentle 2-pole biquads. Even with higher cutoff *numbers*, the extra
   rolloff + Moog coloration crushes the highs.
4. **Manual envelopes at 40 Hz with direct `.amplitude =` writes** → zipper
   noise / clicks instead of the prototype's sample-accurate
   `exponentialRampToValueAtTime`.
5. **Sidechain duck is buggy.** `bassOsc.amplitude = bassOsc.amplitude * duckGain`
   runs every tick and *compounds*, collapsing the bass; `padFader.volume` is
   poked in two places. Causes pumping / missing bass.
6. **Reverb / gain staging.** Algorithmic `Reverb` vs the prototype's generated
   convolution; ~15 voices summed at unity into one `dryMixer` with no per-voice
   level staging → muddy, inconsistent loudness.
7. **Numeric drift vs `ENGINE-SPEC.md`** (e.g. scene pad cutoff `900 + 3600*bright`
   vs spec `350 + 2200*bright`; pad volume `0.045` vs `0.05`).

The **musical logic** (chord tables, motif, step patterns, probabilities, scene
chord-walk) in `+Generators.swift` / `+Scenes.swift` is largely correct and worth
keeping. The **synthesis backend and scheduling** are the problem.

---

## 2. Target architecture

A single real-time DSP core renders the whole mix per-sample on the audio thread;
a lookahead generator enqueues note events with sample-accurate timestamps. This
mirrors Web Audio's model exactly and removes diagnosis items #1–#5 wholesale.

```
[control thread]  setMode/setParameters/...  →  ParamSnapshot (double-buffered)
                                                      │
[scheduler timer] lookahead generator  ──enqueue──▶ EventQueue (lock-free SPSC)
   (musical step logic, beat events)                 │  NoteEvent{startFrame, spec}
                                                      ▼
[audio render thread]  AVAudioSourceNode.render(frameCount):
   for each frame:
     pop due events → allocate Voice from VoicePool
     sum active voices into buses: dry / duck / reverbSend / delaySend
     duck bus  → apply sidechain gain envelope (bass+pads)
     reverbSend → Freeverb → master ;  delaySend → DelayLine → master
     master = (dry + duck + reverb + delay) * volume²  → compressor → out
   publish output RMS → audioLevel
```

### Real-time discipline (non-negotiable)
- **No allocation, no locks, no Swift runtime calls** on the render thread.
- Voices are **pre-allocated** in pools; allocation = pick free / steal oldest.
- Events cross threads via a **single-producer/single-consumer lock-free ring
  buffer** of POD `NoteEvent` structs.
- Param changes cross via an **atomically published snapshot** (double buffer /
  seqlock), never a lock held on the audio thread.

### Voice & DSP primitives
- **Band-limited oscillators (PolyBLEP).** Web Audio's saw/square are
  band-limited; naive saws alias and sound cheap/harsh. Implement sine, saw,
  square, triangle via PolyBLEP, plus white noise. This is essential to "not shitty".
- **Segment envelope.** Generic list of `(target, seconds, curve∈{lin,exp})`
  segments — covers kick amp/pitch sweep, bass, pad attack/hold/release, lead,
  pluck, rhodes, sub swell, noise hits. Exponential segments match the
  prototype's `exponentialRampToValueAtTime`.
- **RBJ biquad** (LP/HP/BP) per voice (bass cutoff sweep, pad, lead, rhodes) and
  static for the noise beds. Replaces `MoogLadder` → fixes "too dark".
- **DelayLine**: circular buffer, dotted-eighth time `spb*0.75`, feedback 0.32,
  wet 0.5, lowpass in feedback path (lead send).
- **Reverb**: Freeverb (8 comb + 4 allpass, Schroeder–Moorer) on the reverb bus.
  Deliberate deviation from the prototype's convolution: lush + cheap + fully
  owned + deterministic; partitioned-FFT convolution is overkill in a notch app.
  **This deviation must be recorded in `ENGINE-SPEC.md`.**
- **Compressor**: simple feed-forward peak compressor on master (threshold −14 dB,
  ratio 4, soft knee) — matches prototype intent and replaces the under-configured
  `DynamicsProcessor`.

### Bus routing (mirrors v2)
- `master = volume²`; into compressor; into output.
- `duck` (pre-master) ← bass, pads; sidechain gain 0.22→1.0 over 300 ms on kick.
- `reverbSend` ← pads, plucks (when `sendRev`), rhodes, texture bed → Freeverb → master.
- `delaySend` ← lead → DelayLine → master.
- dry → master ← kick, noise hits, lead (dry), pluck, dry-pluck, rhodes (dry),
  vinyl bed, texture bed (dry), sub.

### Preserved public API (do not change)
`play()`, `pause()`, `setMode(_:)`, `setParameters(...)`, `setEnergy(_:)`,
`setVolume(_:)`, `setAdaptive(_:)`, `updateContext(_:)`, `beatEvents`,
`audioLevel`. `BeatEvent`, `SoundMode`, `SoundContext`, `SoundEngineParameters`
keep their shapes. `audioLevel` improves from a faked estimate to real master RMS.

---

## 3. File plan (per `refactoring` + `swift-code-quality` skills: ≤300 lines/file, build after each)

New `Packages/MachSoundKit/Sources/MachSoundKit/DSP/`:
- `Oscillator.swift` — phase accumulator + PolyBLEP saw/square/tri, sine, noise.
- `Envelope.swift` — segment envelope (lin/exp), per-sample `tick()`.
- `Biquad.swift` — RBJ LP/HP/BP coefficients + per-sample process.
- `DelayLine.swift` — feedback delay with feedback-path lowpass.
- `Reverb.swift` — Freeverb (comb + allpass banks).
- `Compressor.swift` — feed-forward peak compressor.
- `Voice.swift` — osc(s) + env(s) + optional pitch env + optional biquad + send levels.
- `VoicePool.swift` — fixed-size pool, free/steal-oldest allocation.
- `NoteEvent.swift` — POD spec (waveform, freq, env shape, sends, startFrame).
- `EventQueue.swift` — lock-free SPSC ring buffer of `NoteEvent`.
- `SynthCore.swift` — owns pools + buses + effects; `render(into:frames:sampleTime:)`.
- `ParamSnapshot.swift` — atomically published params/mode/energy/volume.

Rewritten:
- `SoundEngine.swift` — public API + `AVAudioEngine` + `AVAudioSourceNode` + `SynthCore`;
  play/pause; route-change rebuild (keep existing notification handling).
- `SoundEngine+Scheduler.swift` — lookahead generator → enqueues `NoteEvent`s at
  sample frames + yields beat events (replaces the `asyncAfter`/polling scheduler).
- `SoundEngine+Generators.swift` / `SoundEngine+Scenes.swift` — **keep the step/
  chord/motif logic**; change the `trigger*` helpers to build `NoteEvent`s instead
  of poking AudioKit nodes.

Retire after migration: `SoundEngine+Setup.swift` (AudioKit graph),
`SoundEngine+Automation.swift` (25 ms polling), `LeadPluckVoiceHelpers.swift`,
`RhodesVoiceHelper.swift`. Extract-don't-delete: move any still-correct constants
into the new files before removing.

### AudioKit dependency
Keep the `AudioKit`/`SoundpipeAudioKit` package dep **in place initially** so the
Bazel `NotchPluginsWithSoundscape` product and M4b flag setup are untouched. The
new synth uses only `AVFoundation`. Removing the AudioKit dep entirely is an
**optional follow-up** once parity is confirmed (separate, build-infra-aware change).

---

## 4. Phased rollout (each phase builds green + is A/B-testable)

- ✅ **Phase 0 — DSP primitives + tests.** `Oscillator` (PolyBLEP saw/square/tri +
  sine + xorshift noise), `Envelope` (AD-exp + AHR-lin), `Biquad` (RBJ LP/HP/BP),
  `DelayLine` (feedback + LP), `Reverb` (Freeverb), `Compressor`, `EventQueue`
  (lock-free SPSC), `VoicePool` (free/steal-oldest), `NoteEvent` (POD). Live in the
  `MachSoundDSP` module; covered by `DSPPrimitivesTests` (16 tests).
- ✅ **Phase 1 — render path + voice mapping.** `SynthCore.render` through
  `AVAudioSourceNode`; every voice mapped via `NoteEvent` recipes in
  `SoundEngine+Voices.swift` (kick, noise hit, bass, pad, lead, pluck, rhodes
  note/chord, sub swell, vinyl + texture beds). `trigger*` helpers enqueue events.
  All 6 presets sound through the new engine.
- ✅ **Phase 2 — effects + gain staging.** Sidechain duck (0.22→1.0 / 300 ms),
  dotted-eighth `DelayLine` (wet ×0.5), Freeverb on the reverb bus, master
  `Compressor`. Per-voice send/level staging mirrors v2 routing.
- ✅ **Phase 3 — sample-accurate scheduling.** Frame-based lookahead scheduler;
  zero `asyncAfter`; Lo-fi swing as a frame offset; beat events pushed from the
  render thread at the exact event frame via `BeatSink` and drained off-thread.
- ⏳ **Phase 4 — reconcile + tune by ear.** Align cutoffs/volumes with
  `ENGINE-SPEC.md`, record the convolution→Freeverb deviation, A/B every preset.
  **In progress — see §7 for the concrete remaining walkthrough.**

---

## 5. Verification

- **A/B checklist** from `tmp/ENGINE-SPEC.md` §"Required A/B Checklist", per preset
  (Classical×EDM, Epic Ambient, Lo-fi, Focus, Relax, Sleep): brightness/range,
  natural note overlap, preset distinctness, generative feel, kick/bass balance,
  reverb/delay spaciousness without mud.
- **Build paths:** `task run` (Soundscape dev build) for listening; `task run:lite`
  must stay green (AudioKit-free clean build path) per M4b.
- **Unit tests** for all DSP blocks; CI parity with existing `SoundEngineTests`.
- **Done when:** Lars confirms by ear each preset is recognizably close to v2 in
  brightness, variation, voice identity, and listenability (matches M3.5 DoD), and
  CPU/GPU budget stays within the notch-app envelope from M3.

---

## 6. Risks & honest notes

- **Real-time safety is the #1 risk.** Any allocation/lock/ObjC retain on the
  render thread = glitches. Keep `NoteEvent`/voices POD; audit the render path.
- **Aliasing.** Saw/square must be band-limited (PolyBLEP) or it sounds cheap.
- **Reverb cost & character.** Freeverb is the planned compromise; if it doesn't
  satisfy by ear, revisit (partitioned convolution is the expensive fallback).
- **CPU in a menu-bar/notch app.** Cap polyphony, flush idle voices, denormal
  guards; measure against M3's power budget.
- **Spec drift.** Any intended sound change goes into `ENGINE-SPEC.md` first
  (esp. the reverb deviation), then code — same rule as the parent plan.
- **Scope.** This plan covers engine internals only. UI parity (notch surface)
  stays in `PLAN-machSound.md` M3.5 and is not touched here.

---

## 7. Phase 4 walkthrough — remaining parity work (the actual to-do)

Phases 0–3 verified the engine is a **faithful structural port**: a full read-through
against `website/public/fluid-symphony.html` confirmed voices, envelopes,
oscillators, delay, duck, scheduler, and bus routing all match the prototype.
What remains is closing the **perceptual** gap. Ordered by expected audible impact.

### 7.1 Findings log (so we stop re-deriving them)

- **"Doubling / dm-dm-dm / not clear" was largely the master compressor.** The
  prototype's `DynamicsCompressorNode` uses threshold −14, ratio 4, and Web Audio
  *defaults* for the rest: **knee 30 dB, attack 3 ms, release 250 ms**. An earlier
  tuning pass had set ours to knee 18 / release 160 ms — a harder knee and faster
  release, which fully recovers between kicks at 126 BPM and pumps on every beat.
  **Fixed 2026-06-14:** `Compressor.swift` now matches the prototype exactly and
  smooths the *gain reduction* (Web-Audio-style), not the input level. Re-listen
  before chasing anything else.
- **Compressor must detect on a *smoothed level*, not the instantaneous sample.**
  A pass that computed gain reduction from `|x|` then smoothed the gain rippled the
  gain at the signal frequency for low content (kick/bass/sub cross zero each cycle)
  → an audible low buzz layered under everything, on every preset. **Fixed
  2026-06-14:** `Compressor.swift` smooths the level envelope (fast-attack/slow-
  release peak follower) and derives gain from that. Output stage now also drops
  any non-finite sample (`SynthCore+Render.swift`) as insurance against a stuck
  feedback-path value.
- **The DSP core is provably clean offline.** `testEdmBarStats` (4 EDM bars):
  peak ≈ 0.67, DC ≈ 5e-4, active-region noise floor ≈ −63 dB, no NaN/Inf, and the
  render runs ~3× faster than real time. So any *audible* "background noise" that
  persists is a **live/graph-level** artifact (AVAudioEngine format/SRC, device
  session, real-time dropouts), not the synthesis core — investigate the live
  audio graph next, not the voices.
- **The offline onset-counter is not a mix diagnostic.** `OfflineRenderTests`
  `countOnsets` rides a peak-follower with an 80 ms refractory gap; under a
  sustained pad/bass bed the envelope never re-arms, so a full bar reports
  "1 onset". It is valid only for isolated hits (single/four kicks). Do **not**
  read the EDM-bar onset number as evidence of doubling. If we want an objective
  mix diagnostic, replace it with **spectral-flux onset detection** or render
  **isolated stems** (see 7.5).

### 7.2 Reverb: Freeverb vs the prototype's convolution (top remaining gap)

The prototype uses a **generated convolution reverb**: a 3 s stereo impulse,
`(random*2-1) * pow(1 - i/len, 2.6)` — a smooth exponential-decay noise tail. Ours
is Freeverb (Schroeder–Moorer combs+allpasses). This is the single biggest tonal
difference left and a plausible source of "not quite as clean/lush."

- First try tuning Freeverb (`roomSize`, `damping`, comb tunings, stereo spread) to
  approximate a 3 s, gently-damped tail; A/B the Ambient preset (most reverb-exposed).
- If Freeverb can't get there by ear, implement a **lightweight partitioned-FFT
  convolution** with the exact generated impulse. Cost is the concern in a notch
  app — measure against M3's power budget before committing.
- **Whichever path: record the decision in `ENGINE-SPEC.md`** (the
  convolution→Freeverb deviation is still un-recorded per the original plan).

### 7.3 Reconcile remaining numeric drift to `ENGINE-SPEC.md`

Spec-freeze the prototype first (see 7.6), then sweep for residual constant drift
called out in §1.7 of this plan, e.g. scene pad cutoff (`350 + 2200*bright` in spec
vs whatever the code has), pad volume `0.05`, scene reverb-return ranges. The EDM /
Ambient / Lo-fi generators are already aligned; the **scene** generators
(`SoundEngine+Scenes.swift`) are the most likely to still drift.

### 7.4 Voice-level polish candidates (only if still off after 7.2/7.3)

- **Detuned-oscillator phase.** Pads (±7 c) and lead (±9 c) reset both oscillators
  to phase 0 on trigger → identical start phase → a brief comb/whoosh before they
  separate. The prototype's fresh nodes also start at phase 0, so this is likely a
  non-issue, but a small random start-phase on osc2 is a cheap experiment.
- **Kick body.** Confirm the 150→44 Hz exp pitch sweep over `dur*0.5` + exp amp
  decay reads as one clean thump, not click+body, on small speakers.
- **Saw brightness.** PolyBLEP saw vs Web Audio's band-limited saw differ slightly
  in harmonic balance; only chase this if leads/pads still feel dull/harsh after
  the filter cutoffs are reconciled.

### 7.5 Objective A/B tooling (optional but recommended)

- Add a debug build hook to render each preset's first ~8 bars to a WAV offline
  (the harness already exists in `OfflineRenderTests`), so a stem can be compared
  to a captured prototype recording without real-time variance.
- Either fix `countOnsets` (spectral flux) or add **per-bus stem rendering**
  (kick-only, lead-only, full) to localize any future "doubling" report fast.

### 7.6 Definition of done (unchanged from M3.5)

- `ENGINE-SPEC.md` frozen from the v2 prototype, incl. the reverb deviation.
- Lars confirms by ear each preset (Classical×EDM, Epic Ambient, Lo-fi, Focus,
  Relax, Sleep) is recognizably close to v2 in brightness, variation, voice
  identity, and listenability.
- CPU/GPU stays within M3's notch-app power envelope.
- `task run` ships the rich Soundscape build (now AudioKit-free).
