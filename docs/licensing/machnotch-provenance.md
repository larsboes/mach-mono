# machNotch MIT Provenance Ledger

Status values:

- `rewritten`: reauthored in this repository from current behavior/spec.
- `compatible third-party retained`: retained under MIT/BSD-compatible terms with attribution.
- `removed`: no longer shipped.
- `rewrite required`: inherited or unclear expression remains.

Root `LICENSE` and `Apps/machNotch/LICENSE` remain GPL-3.0 until every `rewrite required` row is resolved and human/legal closeout is complete.

| Area | Status | Evidence / next action |
|---|---|---|
| `private/MachWindowSpace.swift` | rewritten | Replaced former `CGSSpace.swift`; no `Parrot`, `avaidyam`, or MPL source notices remain under `Apps/machNotch/machNotch`. Factual CGS symbol names remain because they bind private macOS APIs. Parrot MPL attribution removed from `Apps/machNotch/THIRD_PARTY_LICENSES`. |
| `mediaremote-adapter/` | compatible third-party retained | BSD 3-Clause notice is present in `mediaremote-adapter.pl` and app third-party notices. Current artifact hashes: script `9ac5ed4532ad78431a85dd30e353efeca84391c4b84c760de74399c09cc2f2ca`; framework binary `91eb19837ca9f2779e476dc8e67d12bc28331dd557c87a19b0e45463c739c2fc`; test client `f177cc4a7d79ea5d70f330eac6266884527039196215738373ea813034285c2a`. Before final MIT closeout, attach the upstream repository/release URL or replace the binary with a source-built artifact. |
| `components/Notch/NotchShape.swift` | compatible third-party retained | DynamicNotchKit is MIT-attributed in app third-party notices. Keep unless the migration goal changes from license compatibility to first-party-only code. |
| `sizing/matters.swift` | rewritten | Reauthored as `NotchGeometry` with compatibility wrappers and pure test coverage in `LicenseMigrationReengineeringTests`. |
| `observers/FullscreenMediaDetection.swift` | rewritten | Reauthored around `FullscreenMediaDetectionPolicy` and snapshot conversion; behavior covered by policy tests. |
| `observers/MediaKeyInterceptor.swift` | rewritten | Event tap split from `MediaKeyInput`, `MediaKeyActionRouter`, and `BezelFeedbackPlayer`; router behavior covered by unit tests. |
| `components/Notch/NotchHomeView.swift` | rewritten | Removed stale direct Defaults dependency and reauthored layout sizing expression around local constants. |
| `components/Notch/NotchExtrasMenu.swift` | rewritten | Replaced inherited tile/menu expression with new `NotchMenuTile` implementation and direct current behavior. |
| `components/Notch/NotchHeader.swift` | rewrite required | Audit still needed for original header layout expression. |
| `components/Notch/HeaderButton.swift` | rewrite required | Audit/rewrite still needed for button expression. |
| `components/Notch/NotchSkyLightWindow.swift` | rewrite required | Audit still needed; private SkyLight behavior is fact/API driven, but expression has not been signed off. |
| `extensions/` | rewrite required | Broad utility audit remains. Prefer removing unused helpers first, then rewriting inherited utility expression file by file. |
| `helpers/` | rewrite required | Broad utility audit remains. `TrackingAreaView` appears post-rewrite but needs formal sign-off. |
| `ContentView*` | rewrite required | The PRD still lists `ContentView` as likely carrying original layout structure. |
| `NotchViewCoordinator*` | rewrite required | The PRD still lists this as audit needed. |
| `Core/Controllers/` | rewrite required | ADR previously marked core controllers clean, but PRD still calls out controller audit. Resolve discrepancy before final closeout. |
| `MusicPlugin` | rewrite required | Audit/rewrite remains, especially around MediaRemote adapter boundaries and current behavior parity. |
