---
id: fluid-symphony-integration
status: in_progress
owner: larsboes
source_of_truth: true
decision: native-first (full AVAudioEngine + Metal port is the committed target)
related:
  prototype_v2: website/public/fluid-symphony.html
  engine_rewrite_plan: Plans/PLAN-machSound-DSP-rewrite.md
  plugin_system: docs/Architecture.md
  agent_guidelines: docs/AGENT-GUIDELINES.md
  machnotch_rules: Apps/machNotch/CLAUDE.md
  license_policy: docs/decisions/0003-license-policy.md
  machbrief_ios_prd: Plans/PRDs/machBrief-iOS.md
  machhealth_plan: Plans/PLAN-machHealth.md
last_updated: 2026-06-14
---

# machSound — Fluid Symphony × mach-mono Integration Plan

**Goal:** Build a fully native, personalized, adaptive soundscape system inside
mach-mono — an Endel replacement fed by live data (notch plugins now, HealthKit via
companion soon). Generative audio on AVAudioEngine, fluid visuals on Metal, scenes
and adaptation rules owned end-to-end. Working name: **machSound**
(plugin id: `com.machnotch.soundscape`, engine package: `Packages/MachSoundKit`).

**Decision (supersedes earlier draft):** Native-first. No WKWebView hosting phase.
The HTML prototypes are demoted to *executable reference spec* — they define the
target sound/behavior and stay in `tmp/` for A/B comparison and rapid sound-design
iteration, but no production code ships a WebView.

**Status:** Milestones M0–M3 produced a native engine, plugin, context wiring, and
Metal visualizer. The original AudioKit-node-graph engine could not reach v2 parity,
so the **M3.5 decision gate fired**: the engine internals were rewritten as a
sample-accurate custom DSP core on a single `AVAudioSourceNode`
(see `Plans/PLAN-machSound-DSP-rewrite.md`). As of 2026-06-14 that rewrite is
**structurally complete** (Phases 0–3 done, AudioKit fully removed) and shipping
through `task run`; the remaining work is **Phase 4 — perceptual parity tuning**
(reverb character, spec reconciliation, by-ear A/B). Then M4 (Health pipeline via
iOS exporter).

---

## 0. Non-Goals

- **No cloud, no accounts.** All synthesis, adaptation, and health data stay on-device
  / on-LAN. Same posture as the local-model plan.
- **No Endel content or claims.** Inspiration only. Original synthesis, no
  "neuroscience-backed" claims — we have vibes, not studies.
- **No bundled audio samples.** Synthesized voices only (oscillators, noise, physical
  modeling later). Keeps it honest and tiny.
- **No GPL/MPL dependencies** (ADR 0003). AudioKit (MIT) is acceptable if chosen in M0.
- **Not a music player.** machNotch's MusicPlugin owns real media; machSound yields
  to it automatically, always.
- **No raw health data persistence on Mac beyond derived features** (privacy default:
  compute → use → discard; retention opt-in only).

---

## 1. Costs of Native-First (eyes open)

Going straight to native skips the cheap WebView validation step. Accepted trade-offs:

- **Time-to-first-sound is weeks, not days.** WebAudio gave a free node graph
  (oscillators, biquads, convolver, compressor). Native means building or adopting
  equivalents. Mitigation: M0 evaluates **AudioKit (MIT)** — it provides oscillators,
  filters, reverb, and a sequencer and could collapse M1 by 60–70%. Hand-rolled
  vDSP/AVAudioSourceNode is the fallback if AudioKit feels too heavy.
- **Two implementations drift.** The HTML spec and the Swift engine will diverge
  unless the spec is frozen first (M0) and parity-checked per voice (M1 exit).
- **Metal fluid port is real work** (~5 compute kernels + double-buffered half-float
  textures + display shader). Well-trodden territory, but not a weekend.

Why it's still right here: the repo is Swift/Bazel with strict quality skills, the
WKWebView audio lifecycle is a permanent tax, battery/perf headroom matters in a
notch app, and the owner *wants* to own the DSP. Fine — but the spec freeze is
non-negotiable or we rewrite twice.

---

## 2. Engine Spec (M0 freezes this — extracted from v2)

Single source of truth for both implementations:

- **Modes:** 3 performances (Classical×EDM 126bpm Cm, Epic Ambient 72bpm Am,
  Lo-fi 78bpm Cmaj7-walk) + 3 scenes (Focus 96bpm·maj-pent, Relax 66bpm·min-pent,
  Sleep 52bpm·sparse-minor). Scenes = parameter snapshots over one shared engine.
- **Params (0–1):** pace, density, brightness, space, pulse, texture
  (+ volume, energy). Minute-scale sine drift per param (freq/phase table in v2)
  so scenes never loop. Scenes use random chord-walks through their scale.
- **Layers:** drums / bass / pads / melody / texture — gateable in every mode.
- **Voices:** kick (pitch-swept sine), noise hits (filtered), saw bass + LP env,
  detuned-saw pads (±7c) + LP, supersaw lead (±9c) + dotted-8th delay, sine/tri
  plucks, 2-op "rhodes" (sine + 2× harmonic), vinyl bed, wind texture bed,
  generated-impulse convolution reverb, sidechain duck bus (EDM).
- **Audio→visual contract:** typed beat events {kick, note(midi), bass, chord} +
  continuous low-band amplitude → splat injections + brightness pulse; per-mode
  palettes; time-of-day tint; fluid timescale per scene (sleep 0.45×).
- **Context input (one struct):** daySegment, weather, activity, pomodoro phase,
  calendar proximity, mediaPlaying, health (M4: hr, hrvSDNN, sleepQuality, workout).

Deliverable: `tmp/ENGINE-SPEC.md` with exact tables (notes, step patterns, envelope
times, filter ranges) transcribed from v2 source.

---

## 3. Phases (ordered so live data lands early)

### M0 — Spec freeze + audio stack ADR (partially complete)
- **Active correction:** write `tmp/ENGINE-SPEC.md`. The plan previously claimed
  this existed, but the repo does not contain it. M3.5 must start by freezing the
  v2 reference in this file.
- **Completed**: Spike AudioKit vs Hand-rolled (concluded AudioKit compiles and integrates cleanly).
- **Completed**: Mini-ADR created at `docs/decisions/0011-machsound-audio-stack.md`.

### M1 — MachSoundKit: native audio engine (Completed 2026-06-11)
- **Completed**: Created `Packages/MachSoundKit` containing `SoundEngine` and `SoundContext`. Target compiles with Bazel rules.
- **Completed**: Lookahead scheduler implemented (25ms tick rate on background queue, schedules steps `< now + 180ms`, handles variable BPM, lo-fi swing delays).
- **Completed**: Synthesis voices pre-allocated and implemented via AudioKit/Soundpipe nodes, including dynamic volume/gain routing using Mixer nodes.
- **Completed**: Reverb Send routing, master compressor (DynamicsProcessor), and sidechain ducking implemented.
- **Completed**: Audio routing robustness (listens to `AVAudioEngine.configurationChangeNotification` to pause, rebuild graph, and resume playback).
- **Completed**: Testing coverage - unit tests implemented in `SoundEngineTests.swift` passing successfully with Bazel runner.

### M2 — SoundscapePlugin + live data (Completed 2026-06-12)
- **Completed**: `Plugins/BuiltIn/SoundscapePlugin/` per plugin-architecture skill: `@Observable @MainActor`, DI via `PluginContext`, full teardown in `deactivate()`, namespaced `PluginSettings`, HUD via `PluginEventBus` only.
- **Completed**: Closed-notch: beat-pulsing micro-indicator. Expanded: controls (scene, volume, params) + placeholder visual.
- **Completed**: Event-bus wiring → `SoundContext` (PomodoroPlugin focus/break, MusicPlugin play/pause ducking, WeatherPlugin condition mapping, Calendar proximity, and system-wide idle tracking activity signal).

### M3 — Metal fluid simulation (Completed 2026-06-13)
- **Completed**: Port the 5-pass Stable Fluids pipeline (curl→vorticity→divergence→jacobi×20→gradient-subtract + advection) to Metal compute; rg16f/rgba16f double-buffered textures; MTKView display shader with boost/vignette; splat injection from `BeatEvent` stream + pointer drag.
- **Completed**: Power budget: render only when notch surface visible; ProMotion-aware frame pacing; sim res scales down on battery. CPU/GPU budget measured before/after.

### M3.5 — v2 Parity Stabilization (active)
- **Goal:** make the native Soundscape feel like the Fluid Symphony v2 prototype
  (`website/public/fluid-symphony.html`), not merely share labels and structure.
- **Decision gate RESOLVED → rewrite taken.** AudioKit's prebuilt nodes + 25 ms
  polling could not reach v2 parity. The engine internals were rewritten as a
  sample-accurate custom DSP core (PolyBLEP voices, lock-free event queue, voice
  pool, Freeverb, frame-based scheduler) on a single `AVAudioSourceNode`, behind
  the unchanged `SoundEngine` public API. **AudioKit/SoundpipeAudioKit were
  removed entirely.** Full detail + remaining work:
  → **`Plans/PLAN-machSound-DSP-rewrite.md`** (owns engine internals).

- **M3.5a — Engine rewrite (audio):** Phases 0–3 ✅ done; **Phase 4 (perceptual
  parity tuning) in progress.** Remaining audio walkthrough lives in the rewrite
  plan §7 — top items: reverb character (Freeverb vs the prototype's convolution),
  reconcile residual numeric drift to `ENGINE-SPEC.md` (esp. scene generators),
  freeze `ENGINE-SPEC.md` from v2, by-ear A/B per preset. Compressor parity was
  fixed 2026-06-14 (knee 30 / attack 3 ms / release 250 ms, gain-smoothed).

- **M3.5b — UI parity (still open):** Soundscape needs a notch-native Fluid
  Symphony surface: responsive title/control dock, no Home-tab hijacking, clean
  tab animation, optional compact now-playing surface. Preserve prototype scene
  defaults/labels while adapting controls to notch dimensions; keep Home behavior
  stable; Soundscape lives in its own tab unless a compact now-playing component
  is intentionally designed.

- **Reference contract:** every tuning pass compares against
  `website/public/fluid-symphony.html`; update `tmp/ENGINE-SPEC.md` first for any
  intended behavior change (incl. the recorded convolution→Freeverb deviation).
- **Definition of done:**
  - Lars confirms by ear that each native preset is recognizably close to v2 in
    brightness, variation, voice identity, and listenability.
  - Native Soundscape tab is responsive at notch widths and does not break Home.
  - `task run` launches the rich Soundscape dev build (now AudioKit-free).

### M4 — Health pipeline (self-owned, open source — decided)
- **Constraint (checked 2026-06):** Health store is iPhone/Watch-only; macOS cannot
  query HealthKit.
- **Decision:** no extra hardware, no Watch app, no third-party closed apps
  (Health Auto Export et al. explicitly out — can't rely on them). Self-built,
  open-source pipeline only. Accepted consequence: **minute-scale adaptation, not
  beat-level live HR** (Watch→iPhone HR sync is batchy; background delivery is
  throttled). Fine for an Endel-like. Revisit BLE-strap live track only if
  minute-scale ever feels insufficient.

**Phase 0 — Shortcuts bridge (zero code, this week if wanted):**
- iOS Shortcuts personal automation: "Find Health Samples" (HR, HRV, sleep, steps)
  → "Get Contents of URL" POST to a Mac LAN endpoint. ~15-min granularity,
  time-triggered. Fully self-owned, no apps. Good enough to develop and test the
  Mac-side mapping rules before any Swift is written.

**Phase 1 — machHealth (own open-source exporter — separate plan):**
- **`Apps/machHealth`** is its own project with its own plan:
  → **`Plans/PLAN-machHealth.md`** (source of truth for everything exporter-side).
- machSound's side of the contract: run/embed the **Mac receiver** (Bonjour-
  advertised HTTP listener, paired-token auth), consume the versioned JSON schema,
  derive features (arousal vs baseline, sleepQuality, recovery), discard raw values.
- **Rejected:** encrypted-backup `healthdb_secure.sqlite` live extraction (fragile,
  breaks per iOS release); cloud aggregator APIs; closed third-party export apps.
- **Transport:** local network only — self-built receiver, no external broker or
  third-party infrastructure of any kind.
- **Derived features, not raw streams:** arousal estimate (HR vs personal baseline),
  recovery (HRV SDNN trend), sleepQuality (last night). Mapping rules stay dumb and
  inspectable: e.g. high arousal during Focus → pace/pulse −15%; poor sleep → softer
  morning profile; workout ended → suggest Relax.
- Privacy: derived values only on Mac, retention opt-in, everything visible in a
  "why is it sounding like this?" inspector.

### M4b — Soundscape app opt-in flag (planned)
- Default `//Apps/machNotch:machNotch` intentionally excludes Soundscape and does
  not depend on `Packages/MachSoundKit` / AudioKit.
- Use `NotchPluginsWithSoundscape` for Soundscape-enabled builds/features.
- Add an explicit product/build flag before re-enabling Soundscape in an app
  bundle; do not silently add AudioKit back to the default distribution.

### M5 — Personalization (replace the Endel subscription for real)
- Profiles {scene, params, layers, palette} in `PluginSettings`, JSON export.
- Autoplay rules engine: ordered `(condition, profile)` list — context-driven,
  no ML until the dumb version feels limiting.
- Personal sound identity: per-profile scale/root/voice choices; seedable RNG.
- Custom scenes as data (user-defined SCAPE entries).
- machBrief touchpoint: brief reading over a soundscape bed.

### M6 — Sound maturity (ongoing)
- Karplus–Strong plucks, FM bells, stereo width per layer, better pad filter motion.
- Alternative visual themes behind the same BeatEvent API.

---

## 4. Risks & Honest Notes

- **M1 is the schedule risk.** Synthesis parity is fiddly; expect ear-tuning loops.
  AudioKit decision in M0 is the biggest lever on this.
- **Health adaptation can feel creepy/wrong fast.** HR-reactive music that guesses
  badly is worse than static music. Ship M4 behind a toggle, default off, with the
  inspector from day one.
- **Spec drift.** Any sound change after M0 happens in ENGINE-SPEC.md *first*, then
  in code. The HTML files never change again (they're the v2 archive).
- **Scope magnet:** the rules engine and "AI picks your soundscape" stay out until
  M5's dumb list is lived with.

## 5. Open Questions (answer before M1)

1. AudioKit vs hand-rolled — decided by M0 spike, but: how allergic are we to a
   third-party dep in MachSoundKit's core?
2. Should audio survive machNotch quitting (engine in XPC helper / login agent)?
   Decide intent now; affects where MachSoundKit's process boundary sits.
3. machHealth: standalone `Apps/machHealth` (reusable OSS exporter) or module in
   machBrief iOS? (Recommendation: standalone app, shared HealthKit core package.)
4. Floating ambient window: M3 stretch or M5?

## 6. Immediate Next Steps

1. `tmp/ENGINE-SPEC.md` — transcribe v2 into exact tables (can be done tonight-ish;
   it's extraction, not invention).
2. AudioKit spike: render one detuned-saw pad chord + one swept kick through a
   convolution reverb in a scratch target; judge DX and Bazel fit.
3. Mini-ADR: audio stack decision.
4. Scaffold `Packages/MachSoundKit` skeleton per repo conventions.
