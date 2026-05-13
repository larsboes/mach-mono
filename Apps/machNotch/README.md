<p align="center">
  <img src="machNotch/Assets.xcassets/AppIcon.appiconset/icon_512.png" alt="machNotch logo" width="120">
</p>
<h1 align="center">machNotch</h1>
<p align="center">
  <strong>A native macOS notch utility with a modern plugin architecture, clean dependency injection, and a growing suite of built-in productivity surfaces.</strong>
</p>

<p align="center">
  <a href="https://github.com/larsboes/mach-mono/actions/workflows/cicd.yml">
    <img src="https://github.com/larsboes/mach-mono/actions/workflows/cicd.yml/badge.svg" alt="Build & Test" />
  </a>
</p>

<p align="center">
  <video src="https://github.com/user-attachments/assets/b8912856-6c8c-48bd-9d0c-16ab084ddd59" width="700" autoplay loop muted></video>
</p>

---

## What is machNotch?

machNotch transforms your MacBook's notch into a dynamic control center with music playback, calendar, file shelf, HUD replacements, and more.

The app focuses on:

### Architecture Overhaul
- **Plugin-first architecture** — every feature is a `NotchPlugin`. Built-in features use the same API that future third-party plugins will use.
- **Protocol-based dependency injection** — zero `.shared` singletons in views/services. Everything injected via `@Environment` or init.
- **`@Observable` + `@MainActor`** throughout — no legacy `ObservableObject`/`@Published`.
- **Clean layer boundaries** — Domain, Application, Infrastructure, Presentation layers with enforced import constraints.
- **Service protocols** for all system integrations (music, battery, calendar, weather, shelf, webcam, notifications, clipboard).

### Integrated Community PRs
Cherry-picked and adapted the best community contributions that were pending on upstream:

| Feature | Original PR |
|---------|-------------|
| Sneak peek duration customization | #897 |
| Auto-disable HUD on disconnected displays | #895 |
| Screen recording live activity | #804 |
| Mood face customization | #798 |
| Clipboard history + note-taking (SQLite-backed) | #788 |
| Animated face with mouse tracking | #751 |

### New Plugins
- **Teleprompter Pro** — full-featured teleprompter with countdown timer, mic monitoring, hover-to-pause, keyboard shortcuts, AI text assist (refine/summarize/draft via Ollama), speed/font/color controls
- **Habit Tracker** — daily habit tracking with streaks, progress rings, and persistent storage
- **Pomodoro Timer** — focus timer with work/break intervals, session history, and notch-integrated controls
- **Display Surface** — generic display arbitration for surfacing prioritized content

### AI & Integrations
- **AI subsystem** — `AIManager` + `AIProvider` protocol with Ollama backend for on-device text generation
- **Local API server** — HTTP + WebSocket server for external integrations. Auth middleware, rate limiting, plugin API routes
- **`notchctl` CLI** — command-line control of machNotch via the Local API
- **App Intents & URL Scheme** — Siri Shortcuts integration + `machnotch://` deep links

### Performance
- **Background service backoff** — plugins and services automatically pause polling when the notch is closed (zero idle CPU)
- **Phase 2 efficiency** — isolated high-frequency progress updates into leaf reader views, event-driven geometry, XPC helper backoff
- **TimelineView gating** — music controls switch to static layout when closed (no 60fps background burn)
- **GPU/CoreAnimation backoff** — heavy blur/blend effects gated behind transition state

### Additional Improvements
- **Apple-quality animations** — content reveal modifier, shadow easing, spring-tuned open/close choreography
- **Dual hover zones** — separate closed/open hover detection for accurate mouse tracking
- **Heartbeat-based hover** — replaced event-driven hover with a robust heartbeat controller (11 unit tests)
- **Data export** — `ExportablePlugin` protocol with export UI in Settings
- **SOLID & DDD hardening** — SRP extractions, type-safe `PluginID` enum, domain purity enforcement
- **CI pipeline** — build, test, and architecture boundary checks on every push

---

## System Requirements

- macOS **14 Sonoma** or later
- Apple Silicon or Intel Mac

---

## Building from Source

```bash
brew install bazelisk
git clone https://github.com/larsboes/mach-mono.git && cd mach-mono
bazelisk build //Apps/machNotch:machNotch
open bazel-bin/Apps/machNotch/machNotch.app
```

Bazel uses the Xcode toolchain to compile Swift — Xcode 16 or later must be installed (free from the App Store; no paid developer account needed).

<details>
<summary>Also want to run in Xcode?</summary>

1. `open Apps/machNotch/machNotch.xcodeproj` — Xcode resolves SPM dependencies automatically.
2. Fix code signing for each target (`machNotch`, `MachNotchXPCHelper`, `machNotchTests`): **Signing & Capabilities → Automatically manage signing → set Team to your personal team → change Bundle Identifier** to something unique (e.g. `com.yourname.machnotch`).
3. Press `Cmd + R`.

> If Xcode shows "Missing package product" errors, close and reopen the project.

</details>

### Tests

```bash
bazelisk test //Apps/machNotch:machNotchTests //Packages/MachBriefKit:MachBriefKitTests
```

---

## Browser Extension Setup (For YouTube/Web Media)

To get perfect, sub-second scrubber and duration sync for browser media like YouTube, install the bundled companion extension:

1. Open **Google Chrome** (or Chromium-based browser).
2. Navigate to `chrome://extensions/`.
3. Toggle on **Developer Mode** in the top-right corner.
4. Click **Load Unpacked** in the top-left corner.
5. Select the `machNotch-extension` folder located inside the repository directory.

The extension connects directly to machNotch via a local WebSocket to transmit metadata and receive media commands without any additional config!

---

## Architecture

```
SwiftUI Views -> PluginManager -> NotchPlugin instances -> Service Protocols -> System APIs
```

Every feature is a plugin. Plugins communicate via `PluginEventBus`, never by importing each other. See [docs/architecture/overview.md](../../docs/architecture/overview.md) for the full reference and [docs/guides/plugin-development.md](../../docs/guides/plugin-development.md) for the plugin development guide.

---

## Acknowledgments

All credit for the original boring.notch concept and implementation goes to [TheBoredTeam](https://github.com/TheBoredTeam). machNotch builds on that foundation while moving into the mach-mono suite.

- **[MediaRemoteAdapter](https://github.com/ungive/mediaremote-adapter)** — Now Playing source support for macOS 15.4+
- **[NotchDrop](https://github.com/Lakr233/NotchDrop)** — Foundation for the Shelf feature

For a full list of licenses and attributions, see [THIRD_PARTY_LICENSES](./THIRD_PARTY_LICENSES.md).
