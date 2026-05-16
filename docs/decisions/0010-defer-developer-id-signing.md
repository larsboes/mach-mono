# 0010 — Defer Developer ID Signing and Notarization

- Status: Accepted
- Date: 2026-05-16

## Context

Released DMGs (`v1.3.2` and forward) are produced by `build_reusable.yml` with `CODE_SIGN_IDENTITY: "-"` — ad-hoc signing. This is sufficient to satisfy `codesign` and to package a runnable bundle into a DMG, but it is **not** a Developer ID-signed nor notarized build.

User impact on macOS Sequoia (13+) and Sonoma (14+):

- Double-clicking the downloaded DMG mounts fine.
- Dragging `machNotch.app` to Applications works.
- First launch shows: **"machNotch can't be opened because Apple cannot check it for malicious software."**
- The Open button is not available from the Gatekeeper dialog — the user must either:
  - Right-click the app in Finder → **Open** → confirm the secondary dialog, **or**
  - Run `xattr -dr com.apple.quarantine /Applications/machNotch.app` from Terminal, **or**
  - In System Settings → Privacy & Security, click **Open Anyway** on the blocked-app notice that appears after the first attempt.

Notarization would eliminate the warning entirely. It requires:

1. A paid Apple Developer Program membership (~$99/yr).
2. A Developer ID Application certificate in the build keychain.
3. App-specific password or App Store Connect API key for `xcrun notarytool submit --wait`.
4. `xcrun stapler staple` on both the `.app` and the `.dmg`.

## Decision

**Defer Developer ID signing and notarization indefinitely.** Ship ad-hoc-signed DMGs. Document the Gatekeeper workaround on the install page and accept the trust friction as a known limitation for the duration of the deferral.

Rationale:

- Project is currently a personal / open-source effort without a budget line for the Developer Program membership.
- The technical pipeline (Bazel → codesign → DMG → Sparkle appcast) is correct and only the **identity** is missing — flipping the switch later is a config change, not a rewrite.
- Users who care enough to download a notch utility from GitHub generally already know the right-click-Open workaround.

## Consequences

Accepted:

- Every release will trigger a Gatekeeper warning on first launch.
- The README install section and `docs/guides/sideloading.md` must document the workaround so users don't bounce.
- Sparkle auto-update will still work (ed25519 signatures are independent of Developer ID), but the **first** install still hits the warning.
- The CHANGELOG `v1.3.2` entry already notes this as a known limitation.

Future revisit triggers — re-evaluate this ADR if any of:

1. A sponsor or income stream covers the Developer Program fee.
2. Distribution moves to a context where unnotarized binaries are blocked outright (e.g., MDM-managed Macs in a target user base).
3. Sequoia or a later macOS version removes the right-click-Open workaround.
4. The project ships a mach.brief iOS app — App Store distribution requires a developer account anyway, at which point notarizing the Mac side is incremental cost.

## Related

- `build_reusable.yml` — emits `CODE_SIGN_IDENTITY: "-"`
- `release.yml` — orchestrates the unsigned release flow
- CHANGELOG `v1.3.2` — "v1.3.1 was tagged… produced no artifact. v1.3.2 supersedes it." (transparency note about the build path fix, not notarization)
