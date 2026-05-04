## Learned User Preferences
- User prioritizes making `mach-mono` feel like its own `machNotch` project, not a lingering `boring.notch` fork; clean up stale `boring*` names in code and docs except attribution, license, and dependency history.
- User expects repo docs, CI, build commands, and PRD status to stay aligned with the current root workspace and `main`-only workflow.
- When following the PRD, user prefers finishing the active in-progress phase before jumping to another roadmap item.
- User values build and test verification after Swift/Xcode changes, especially through the root workspace when available.
- User likes notch plugins to offer lightweight hover previews with richer clicked/expanded views, following the Battery plugin interaction pattern.
- User prefers weather/ambient UI animation to stay minimal, aesthetic, low-resource, and respectful of Reduce Motion.

## Learned Workspace Facts
- `mach-mono.xcworkspace` is the root workspace and currently references `Apps/machNotch/machNotch.xcodeproj`; the primary app scheme is `machNotch`.
- The app lives under `Apps/machNotch`, with app-specific instructions in `Apps/machNotch/CLAUDE.md`; shared packages under `Packages/` are not yet populated.
- Built-in plugin registration lives in `Apps/machNotch/machNotch/Plugins/Core/PluginRegistry.swift` via `PluginRegistry.makeBuiltInPlugins()`.
- Plugin services belong under `Apps/machNotch/machNotch/Plugins/Services` and are wired through service provider protocols and `ServiceContainer`.
- The repo uses a `main`-only branch model unless maintainers explicitly add another branch.
- Weather uses OpenWeatherMap as the primary source in Auto mode, with WeatherKit as fallback when available; normal weather fetches reuse fresh in-memory data for 30 minutes.
