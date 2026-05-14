# Release Runbook

How to cut a release of mach.notch from tag to published GitHub release.

## Prerequisites

All of the following GitHub repository secrets must be set before the first release:

| Secret | What it is | How to generate |
|--------|-----------|-----------------|
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded `.p12` Apple Development certificate | Export from Keychain → base64 encode |
| `P12_PASSWORD` | Password protecting the `.p12` file | Set when exporting from Keychain |
| `KEYCHAIN_PASSWORD` | Temporary CI keychain password | Any random string |
| `PRIVATE_SPARKLE_KEY` | Sparkle EdDSA private key for signing the appcast | See below |

### Generating the Sparkle EdDSA key (one-time setup)

```sh
# From the repo root — generates a key pair in the Sparkle tool directory
Apps/machNotch/Configuration/sparkle/generate_keys
```

The tool prints both keys:
- **Public key** → paste into `Apps/machNotch/machNotch/Info.plist` under `SUPublicEDKey`
- **Private key** → store as the `PRIVATE_SPARKLE_KEY` GitHub Actions secret (never commit this)

The public key is already in the repo. Only run `generate_keys` if you need to rotate.

## Release workflow

### 1. Verify the build is green

Ensure the latest commit on `main` passes CI (`cicd.yml` — build + test jobs).

### 2. Update CHANGELOG.md

Add a new versioned section at the top of the file, above the current latest entry:

```markdown
## v1.4.0 — YYYY-MM-DD

### ✨ New features
- ...

### 🐛 Bug fixes
- ...
```

Commit directly to `main`: `git commit -m "chore: prep release v1.4.0"`.

### 3. Push the tag

Tag format is `v<semver>` — examples: `v0.2.0`, `v0.2.0-beta.1`.

```sh
git tag v0.2.0
git push origin v0.2.0
```

Beta/RC tags (containing `beta` or `rc`) are automatically published as pre-releases.

### 4. Watch the release pipeline

`release.yml` triggers on the tag push and runs three jobs in sequence:

1. **Preparation** — extracts version and build number from the tag
2. **Build and sign** (`build_reusable.yml`) — Bazel build → codesign → DMG
3. **Publish** — generates signed Sparkle appcast → commits `appcast.xml` to `main` → creates GitHub release with DMG attached

Monitor at: `https://github.com/larsboes/mach-mono/actions`

### 5. Verify the release

After the pipeline completes:
- GitHub release exists with the correct tag and DMG attached
- `Apps/machNotch/updater/appcast.xml` in `main` has the new version entry
- Sparkle update check from an installed app picks up the new release

## Signing notes

The app is signed with an **Apple Development** certificate, not a Developer ID. Users who download the DMG from GitHub Releases must bypass Gatekeeper once on first install:

```
Right-click app → Open → Open
# or
xattr -dr com.apple.quarantine /Applications/machNotch.app
```

Subsequent updates via Sparkle are automatic and do not require this step.

## Troubleshooting

**Appcast push fails:** The `git push origin main` in the publish job can fail if main advanced since the tag was cut. The pipeline now runs `git pull --rebase origin main` before committing, which handles this. If it still fails, rerun the publish job.

**DMG not attached to release:** The DMG is uploaded as a GitHub Actions artifact by the build job and downloaded by the publish job. If the artifact is missing, rerun the build job.

**Sparkle rejects the update:** The `PRIVATE_SPARKLE_KEY` secret does not match the `SUPublicEDKey` in Info.plist. Regenerate the key pair and update both the secret and the plist.
