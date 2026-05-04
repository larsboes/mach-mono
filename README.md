<h1 align="center">
  <br>
  <strong>mach-mono</strong>
  <br>
</h1>

<p align="center">
  A monorepo of focused macOS quality-of-life utilities — built on a hardened, plugin-first architecture.
</p>

<p align="center">
  <a href="https://github.com/larsboes/mach-mono/stargazers">
    <img src="https://img.shields.io/github/stars/larsboes/mach-mono?style=social" alt="GitHub stars"/>
  </a>
  <a href="https://github.com/larsboes/mach-mono/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-GPL%20v3-blue.svg" alt="License: GPL v3"/>
  </a>
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B-lightgrey?logo=apple" alt="macOS 14+"/>
  <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift" alt="Swift 6.0"/>
</p>

---

## Design System

This monorepo adheres to a strict **Minimalistic Aesthetic**. 

> **Core Principles:** Clarity, Cohesion, Tech-Forward, Subtlety.
> 
> See [.agent/rules/DESIGN.md](.agent/rules/DESIGN.md) for full guidelines.

---

## What is Mach?

**Mach** is named after the [Mach microkernel](https://en.wikipedia.org/wiki/Mach_(kernel)) — the foundational layer that powers macOS itself. The name reflects the goal: a solid architectural foundation that macOS utilities can be built on top of, fast and reliably.

`mach-mono` is a monorepo housing a growing suite of native macOS utilities. Each app is a focused SwiftUI product sharing common architectural conventions and — where it earns its keep — shared Swift packages.

---

## Apps

### `mach.notch` — Notch Utility
> Transforms the MacBook notch into an interactive, plugin-driven command surface.

machNotch is focused on architectural quality: DDD layer boundaries, a SOLID plugin system, full dependency injection, and zero singletons in views or services. Every feature is a plugin — music, media controls, calendar, habits, pomodoro, shelf, teleprompter, battery, webcam, notifications, clipboard, weather, and more.

- **Location:** `Apps/machNotch/`
- **Requires:** macOS 14.0+, MacBook with notch

---

## Repository Structure

```
mach-mono/
├── .agent/                  # Agent workflows and skills
├── .claude/                 # Claude Code rules
├── .github/                 # CI/CD workflows, issue templates
├── Apps/
│   └── machNotch/           # mach.notch — notch utility
│       ├── machNotch/       # Swift source
│       ├── MachNotchXPCHelper/
│       ├── machNotchTests/
│       └── machNotch.xcodeproj
├── docs/
│   └── PRD.md               # Active implementation plan + feature roadmap
├── Packages/                # Shared Swift packages (grows with each new app)
├── resources/               # Demo assets, scripts
└── mach-mono.xcworkspace    # Open this to work on the whole suite
```

---

## Getting Started

**Open in Xcode (recommended):**

```bash
git clone https://github.com/larsboes/mach-mono.git
cd mach-mono
open mach-mono.xcworkspace
```

Select the `machNotch` scheme and run. That's it — no `cd` into subdirectories needed.

**Build from command line:**

```bash
xcodebuild -workspace mach-mono.xcworkspace -scheme machNotch \
  -destination 'platform=macOS' build 2>&1 | tail -50
```

**Run tests:**

```bash
xcodebuild -workspace mach-mono.xcworkspace -scheme machNotch \
  -destination 'platform=macOS' test 2>&1 | tail -50
```

---

## Roadmap

- [x] `mach.notch` — notch utility (shipped)
- [ ] `mach.window` — window snapping + DockDoor-style hover peek
- [ ] `mach.bar` — menu bar companion (OneMenu-inspired)
- [x] `HabitTracker` plugin — daily habits with streaks and progress rings (shipped)
- [~] `SystemStats` plugin — CPU/GPU/RAM/disk/network rings in the notch (in progress)
- [ ] `PreventSleep` plugin — IOKit sleep prevention toggle
- [ ] `ExternalBrightness` plugin — DDC monitor brightness control
- [ ] `ColorPicker` plugin — screen color sampler with history
- [ ] `FocusMode` plugin — active Focus indicator in notch
- [ ] `MenuBar` plugin — absorb menu bar icons into the notch
- [ ] Shared `MachUI` package — design system across all apps

See [`docs/PRD.md`](docs/PRD.md) for the full implementation plan.

---

## Requirements

- macOS 14.0 or later (optimised for macOS 15+)
- MacBook with a notch (for `mach.notch`)
- Xcode 16+ to build from source

---

## Acknowledgments

`mach-mono` builds on the shoulders of several exceptional open-source projects:

- [**boring.notch**](https://github.com/TheBoredTeam/boring.notch) — the foundational notch utility this fork originated from. The plugin architecture, media integration, shelf, and core notch interaction model all trace back here. An outstanding project by TheBoredTeam.

- [**Atoll**](https://github.com/Ebullioscopic/Atoll) — a feature-rich notch utility that expanded on boring.notch with live activities, lock screen widgets, system stats, and more. A major source of feature inspiration for what this suite aims to become.

- [**DockDoor**](https://github.com/ejbills/DockDoor) — window peeking, alt-tab, and dock enhancements for macOS. Inspiration for the upcoming `mach.window` app.

- [**MacroVisionKit**](https://github.com/TheBoredTeam/MacroVisionKit) — real-time fullscreen and window state detection framework powering the notch's context awareness.

- [**Stats**](https://github.com/exelban/stats) — reference implementation for macOS system metrics (CPU, GPU, memory, network, disk) via SMC and IOReport bindings.

- [**SkyLightWindow**](https://github.com/Lakr233/SkyLightWindow) — private API window rendering techniques.

- [**KeyboardShortcuts**](https://github.com/sindresorhus/KeyboardShortcuts), [**Defaults**](https://github.com/sindresorhus/defaults), [**Sparkle**](https://sparkle-project.org), [**Lottie**](https://github.com/airbnb/lottie-ios) — essential macOS development libraries used throughout.

---

## License

`mach-mono` is released under the **GNU General Public License v3.0** — see [LICENSE](LICENSE) for the full terms.

This project incorporates code from [boring.notch](https://github.com/TheBoredTeam/boring.notch) (GPL v3). Derivative works must remain GPL v3 and open source.
