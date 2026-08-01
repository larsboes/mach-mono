# 0003 — License policy for new code

- Status: Accepted
- Date: 2026-05-04

## Context

`machNotch` inherited GPL v3 licensing from its BoringNotch history. The long-term goal is to reengineer inherited code and move the root and machNotch to MIT when legally and technically appropriate. New clean-slate apps and packages do not need to inherit that constraint.

## Decision

New apps and packages target MIT from creation.

Do not add GPL or MPL dependencies to new clean-slate apps or packages. For machNotch plugins inspired by GPL projects, independently reimplement the feature, write no code from the reference project, and document a license note in the relevant PRD spec.

## Consequences

- `repo.yaml` tracks current and target license state.
- `Plans/PRDs/machNotch.md` remains the source of truth for the machNotch GPL-to-MIT migration plan.
- `docs/Licensing.md` tracks file/bucket-level provenance evidence for closeout.
- Root `/LICENSE` should be updated only after machNotch is clean for relicensing.

## Migration Checklist (GPL → MIT)

Track remaining BoringNotch-origin code. Check off as each area is reengineered from scratch.

### Infrastructure (reengineered — no BoringNotch code remaining)

- [x] Plugin system (`NotchPlugin`, `PluginManager`, `PluginEventBus`, `ServiceContainer`)
- [x] State machine (`NotchStateMachine`, `NotchPhase`, `NotchPhaseCoordinator`)
- [x] Window management (`NotchSkyLightWindow`, `WindowCoordinator`)
- [x] Settings system (`DefaultsNotchSettings`, sub-protocols, `MockNotchSettings`)
- [x] DI root (`AppObjectGraph`, `ServiceContainer`)
- [x] All `Core/` coordinators and controllers
- [x] `ViewModel/NotchViewModel` and extensions
- [x] All `Plugins/BuiltIn/` — independently implemented features

### Provenance ledger started

- [x] `docs/Licensing.md` — working evidence ledger created
- [x] `private/MachWindowSpace.swift` — private API wrapper verified clean of remaining Parrot/MPL references
- [x] `mediaremote-adapter/` — BSD notice retained; artifact hashes recorded, upstream URL still required before final closeout
- [x] `observers/FullscreenMediaDetection.swift` — reauthored policy
- [x] `observers/MediaKeyInterceptor.swift` — split and reauthored
- [x] `components/Notch/NotchHomeView.swift` — reauthored
- [x] `components/Notch/NotchExtrasMenu.swift` — reauthored
- [x] `sizing/matters.swift` — reauthored as `NotchGeometry`

### Still needs formal audit / sign-off

- [ ] `extensions/` directory — Swift extensions audit
- [ ] `helpers/` directory — utility helpers audit
- [ ] Remaining `components/Notch/` files — header/buttons/SkyLight chrome audit
- [ ] `ContentView*` — notch shell/layout audit
- [ ] `NotchViewCoordinator*` — coordinator audit
- [ ] `Core/Controllers/` — reconcile PRD/ADR status discrepancy
- [ ] `MusicPlugin` — audit plugin logic and MediaRemote boundaries

### Legal steps (after all code is clean)

- [ ] Update `Apps/machNotch/LICENSE` from GPL-3.0 to MIT
- [ ] Update root `/LICENSE` from GPL-3.0 to MIT
- [ ] Update `repo.yaml` `license.current` fields
- [ ] Add MIT license header to reengineered files (optional, best practice)
- [ ] Announce relicense in release notes
