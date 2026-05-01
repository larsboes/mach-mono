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

## What is Mach?

**Mach** is named after the [Mach microkernel](https://en.wikipedia.org/wiki/Mach_(kernel)) — the foundational layer that powers macOS itself. The name reflects the goal: a solid, architectural foundation that macOS utilities can be built on top of, fast and reliably.

`mach-mono` is a monorepo housing a growing suite of macOS utilities. Each app is a focused, native SwiftUI product. They share a common design language, architectural conventions, and — where it makes sense — shared Swift packages.

---

## Apps

### `boringNotch` — Notch Utility
> Transforms the MacBook notch into an interactive, plugin-driven command surface.

A hardened fork of [boring.notch](https://github.com/TheBoredTeam/boring.notch) with a focus on architectural quality: DDD layer boundaries, SOLID plugin system, full dependency injection, and zero singletons in views or services. Every feature is a plugin — music, media controls, calendar, habits, pomodoro, shelf, teleprompter, battery, webcam, notifications, and more.

- **Location:** `Apps/boringNotch/`
- **Requires:** macOS 14.0+, MacBook with notch
- **Build:** `xcodebuild -scheme boringNotch -destination 'platform=macOS' build`

---

## Repository Structure

```
mach-mono/
├── Apps/
│   └── boringNotch/         # Notch utility (hardened boring.notch fork)
├── Packages/                # Shared Swift packages (added as the suite grows)
└── mach-mono.xcworkspace    # Xcode workspace (coming soon)
```

New apps join `Apps/` as independent targets. Shared code that earns its keep gets extracted into `Packages/`.

---

## Roadmap

- [ ] `boringWindow` — window management utility
- [ ] `boringBar` — menu bar companion
- [ ] Shared `MachUI` Swift package — design system across all apps
- [ ] Shared `MachCore` Swift package — common system services

---

## Requirements

- macOS 14.0 or later (optimised for macOS 15+)
- MacBook with a notch (for `boringNotch`)
- Xcode 16+ to build from source

---

## Building

Clone the repo and open the relevant app:

```bash
git clone https://github.com/larsboes/mach-mono.git
cd mach-mono/Apps/boringNotch
open boringNotch.xcodeproj
```

---

## Acknowledgments

`mach-mono` builds on the shoulders of several exceptional open-source projects:

- [**boring.notch**](https://github.com/TheBoredTeam/boring.notch) — the foundational notch utility this fork originated from. The plugin architecture, media integration, shelf, and core notch interaction model all trace back here. An outstanding project by TheBoredTeam.

- [**Atoll**](https://github.com/Ebullioscopic/Atoll) — a feature-rich notch utility that expanded on boring.notch with live activities, lock screen widgets, system stats, and more. A major source of feature inspiration for what this suite aims to become.

- [**DockDoor**](https://github.com/ejbills/DockDoor) — window peeking, alt-tab, and dock enhancements for macOS. Inspiration for the upcoming window management utility in this suite.

- [**MacroVisionKit**](https://github.com/TheBoredTeam/MacroVisionKit) — real-time fullscreen and window state detection framework powering the notch's context awareness.

- [**Stats**](https://github.com/exelban/stats) — the reference implementation for macOS system metrics (CPU, GPU, memory, network, disk) via SMC and IOReport bindings.

- [**SkyLightWindow**](https://github.com/Lakr233/SkyLightWindow) — private API window rendering techniques.

- [**KeyboardShortcuts**](https://github.com/sindresorhus/KeyboardShortcuts), [**Defaults**](https://github.com/sindresorhus/defaults), [**Sparkle**](https://sparkle-project.org), [**Lottie**](https://github.com/airbnb/lottie-ios) — essential macOS development libraries used throughout.

---

## License

`mach-mono` is released under the **GNU General Public License v3.0** — see [LICENSE](LICENSE) for the full terms.

This project incorporates code from [boring.notch](https://github.com/TheBoredTeam/boring.notch), [Atoll](https://github.com/Ebullioscopic/Atoll), and [DockDoor](https://github.com/ejbills/DockDoor), all of which are also GPL v3. Derivative works must remain GPL v3 and open source.
