# Fluid Symphony v2 Engine Spec

Executable reference: [`website/public/fluid-symphony.html`](../website/public/fluid-symphony.html).

This file freezes the behavior the native `Packages/MachSoundKit` engine must
match before adding new adaptation features (M4 health, M5 personalization).

## Presets

| Preset | Label | BPM | Key / Shape |
|---|---:|---:|---|
| `edm` | `CLASSICAL × EDM · 126 BPM` | 126 | C minor, Beethoven-5-style motif over Cm-Ab-Bb-G |
| `ambient` | `EPIC AMBIENT · 72 BPM` | 72 | A minor, broad pads and sparse shimmer |
| `lofi` | `LO-FI · 78 BPM` | 78 | C-family jazzy 7ths, swung offbeats |
| `focus` | `FOCUS` | `96 * (0.75 + 0.5 * pace)` | C major pentatonic scene |
| `relax` | `RELAX` | `66 * (0.75 + 0.5 * pace)` | A minor pentatonic scene |
| `sleep` | `SLEEP` | `52 * (0.75 + 0.5 * pace)` | D sparse minor scene |

## Global Defaults

| Parameter | v2 Default |
|---|---:|
| `volume` | `0.65` |
| `energy` / `intensity` | `0.7` |
| `pace` | `0.5` |
| `density` | `0.5` |
| `brightness` | `0.5` |
| `space` | `0.5` |
| `pulse` | `0.4` |
| `texture` | `0.4` |

## Scene Defaults

| Scene | pace | density | brightness | space | pulse | texture | fluid speed |
|---|---:|---:|---:|---:|---:|---:|---:|
| Focus | 0.55 | 0.50 | 0.60 | 0.35 | 0.55 | 0.35 | 1.00 |
| Relax | 0.40 | 0.35 | 0.42 | 0.60 | 0.30 | 0.45 | 0.70 |
| Sleep | 0.22 | 0.15 | 0.20 | 0.85 | 0.15 | 0.55 | 0.45 |

## Parameter Drift

Each effective parameter is:

```text
slider + 0.08 * sin(2π * frequency * time + phase)
```

| Parameter | Frequency | Phase |
|---|---:|---:|
| pace | 0.0035 | 0.0 |
| density | 0.0061 | 2.1 |
| brightness | 0.0047 | 4.2 |
| space | 0.0028 | 1.3 |
| pulse | 0.0072 | 3.4 |
| texture | 0.0041 | 5.5 |

If adaptive mode is active, `density`, `pace`, and `pulse` also add:

```text
(activityLevel - 0.3) * 0.18
```

## Voices

- **Kick:** pitch-swept sine (`fHi → fLo` over `dur * 0.5`), exponential gain decay to `0.001`.
- **Noise hits:** filtered one-shot noise (hats, claps, snares, crackle).
- **Bass:** saw through lowpass envelope, routed through duck bus.
- **Pads:** detuned saw pairs at ±7 cents per chord tone, lowpass, attack/release envelope, dry + reverb send.
- **Lead:** detuned saw pair at ±9 cents, lowpass, fast attack, dotted-eighth delay send.
- **Pluck:** sine or triangle one-shot, reverb send by default.
- **Rhodes:** sine fundamental + second harmonic at 0.28 gain.
- **Texture bed (scenes):** filtered noise loop; gain `0.012 + 0.022 * texture`; LP cutoff `250 + 2800 * brightness`.
- **Vinyl bed (Lo-Fi):** HP 600 / LP 4200 on white noise; gain `0.012` when Lo-Fi texture layer is on.

## Effects & Buses

| Effect | v2 | Native (`MachSoundDSP`) |
|---|---|---|
| Master gain | `volume²` | `volume²` via `SynthControls.masterGain` |
| Sidechain duck | `0.22 → 1.0` over 300 ms on kick | Same (`SynthCore.startDuck`) |
| Delay | dotted 8th `spb * 0.75`, feedback `0.32`, wet `0.5` | `DelayLine`, same constants |
| Reverb send gain | EDM `0.16`, Ambient `0.55`, Lo-Fi `0.22`, scenes `0.1 + 0.6 * space` | Same per-mode table in `SoundEngine+Controls` |
| Compressor | threshold −14 dB, ratio 4, knee 30 dB, attack 3 ms, release 250 ms | `Compressor.swift`, gain-smoothed level detector |

### Reverb deviation (recorded)

**v2:** generated stereo convolution impulse — 3 s, `(random*2-1) * pow(1 - i/len, 2.6)`.

**Native:** mono Freeverb (Schroeder–Moorer, 8 comb + 4 allpass) in `MachSoundDSP/Reverb.swift`.
Tuned 2026-06-18 for a longer, gentler tail on Ambient (room `0.94`, damping `0.28`,
input gain `0.020`, feedback `roomSize * 0.32 + 0.68`). Per-preset room/damping in
`SoundEngine+Controls.currentControls`.

Partitioned-FFT convolution remains the fallback if Freeverb still falls short by ear.

## Scene Generator Constants

| Voice | Formula |
|---|---|
| Pad cutoff | `350 + 2200 * brightness` |
| Pad volume | `0.05` |
| Pad attack | `1.0 + 2.5 * (1 - pace)` |
| Pad release | `3.0` |
| Sub swell peak | `0.10 + 0.10 * (1 - brightness)` |
| Kick (scene) | `65 + 50 * pulse → 36`, dur `0.45 + 0.5 * (1 - pace)`, vol `0.14 + 0.34 * pulse` |
| Pluck volume | `0.028 + 0.05 * density` |
| Shimmer | `s % 16 == 8`, prob `0.18 * brightness`, vol `0.018`, dur `2.2` |

## Required A/B Checklist

For each preset, compare v2 HTML and native Soundscape:

- Tonal brightness and pitch range.
- Whether notes overlap naturally without cutting each other off.
- Whether presets are clearly distinct.
- Whether melody/pluck/lead events feel generative rather than loop-like.
- Kick and bass balance.
- Reverb/delay spaciousness without mud.
- Visual fluid motion and audio-event response.
- Notch UI fit at normal open width and narrow/home contexts.

## Native Implementation Status (2026-06-18)

- Engine: sample-accurate `AVAudioSourceNode` + `MachSoundDSP` (AudioKit removed).
- Scheduling: frame-based lookahead, no `asyncAfter`.
- Offline harness: `OfflineRenderTests` renders all six presets and checks finiteness.
- Remaining gate: owner by-ear sign-off per preset against the HTML reference.
