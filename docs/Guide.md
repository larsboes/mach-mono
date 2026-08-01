# mach-mono Guides & Runbooks

This file is the single consolidated guides reference for `mach-mono`.

---

## Installation

### DMG

Download the latest `.dmg` from the [GitHub Releases page](https://github.com/larsboes/mach-mono/releases). Open the DMG, drag **mach.notch** to `/Applications`, then launch it.

The DMG build is unsigned/not notarized. macOS will warn that it cannot verify the developer on first launch.

<details>
<summary><strong>Open the DMG build on macOS</strong></summary>

1. Open the downloaded `.dmg`.
2. Drag **mach.notch** into `/Applications`.
3. In Finder, open `/Applications`.
4. Right-click **mach.notch** and choose **Open**.
5. Click **Open** again in the macOS warning dialog.

If macOS still blocks the app, remove the quarantine flag once:

```sh
xattr -dr com.apple.quarantine /Applications/machNotch.app
```

This is the expected tradeoff for the no-paid-Apple-account distribution path.

</details>

### Build locally

Build locally when you want to run straight from the source tree instead of downloading the DMG. Both paths use the same build command after the source is on disk.

If Homebrew is not installed yet, install it from <https://brew.sh/>.

<details>
<summary><strong>Git</strong></summary>

Install the required command-line tools:

```sh
brew install git
brew install bazelisk go-task
```

You also need Xcode installed from the Mac App Store. Open Xcode once so it can finish installing its command-line components.

Clone the repository and run the app:

```sh
git clone https://github.com/larsboes/mach-mono.git
cd mach-mono
task run
```

`task run` builds mach.notch with Bazel, installs it to `~/Applications/machNotch.app`, signs it with your local Apple Development identity, and launches it.

If signing fails, list your local signing identities:

```sh
security find-identity -v -p codesigning
```

If no Apple Development identity appears, add your Apple ID in **Xcode → Settings → Accounts** and let Xcode create a Personal Team certificate.

Then update the `CERT` value in `Taskfile.yml` to match your local Apple Development identity and run `task run` again.

</details>

<details>
<summary><strong>ZIP</strong></summary>

Install the required command-line tools:

```sh
brew install bazelisk go-task
```

You also need Xcode installed from the Mac App Store. Open Xcode once so it can finish installing its command-line components.

Download the repository ZIP from GitHub:

1. Open <https://github.com/larsboes/mach-mono>.
2. Click **Code**.
3. Click **Download ZIP**.
4. Unzip the download.

Run the app from the unzipped folder:

```sh
cd ~/Downloads/mach-mono-main
task run
```

If your browser or unzip tool creates a different folder name, `cd` into that folder instead. `task run` builds mach.notch with Bazel, installs it to `~/Applications/machNotch.app`, signs it with your local Apple Development identity, and launches it.

If signing fails, list your local signing identities:

```sh
security find-identity -v -p codesigning
```

If no Apple Development identity appears, add your Apple ID in **Xcode → Settings → Accounts** and let Xcode create a Personal Team certificate.

Then update the `CERT` value in `Taskfile.yml` to match your local Apple Development identity and run `task run` again.

</details>

### Grant Accessibility access

On first launch, macOS will ask for Accessibility permission — this is the only required permission. Click **Open System Settings**, find **mach.notch** in the list, and toggle it on. The app needs this to detect your cursor hovering over the notch and to intercept media keys.

If macOS or mach.notch offers **Don't Ask Again** for a prompt you have already handled, you can click it to make setup faster. You can still change permissions later in **System Settings → Privacy & Security**.

### Hover to open

Move your cursor over the notch at the top of your screen — it expands. Move away and it closes. Open **Settings** (gear icon in the notch header, or from the menu bar icon) to enable plugins and customise behaviour.

## Permissions

mach.notch asks for permissions only so the selected features can work. There is no analytics backend, and private app data is not uploaded by mach.notch. Features that fetch outside content, such as weather or lyrics, contact their provider only when that feature is used. If you are unsure, the code is open: inspect the repository and verify the behavior directly.

### Accessibility [Required]

Mouse tracking for hover-to-open and media key interception. Without this the notch won't respond.

### Calendar & Reminders [Optional]

Needed by the Calendar plugin to show your events and reminders. Grant when prompted or in System Settings → Privacy.

### Location [Optional]

Used by the Weather plugin for automatic location detection. You can also enter a location manually.

### Camera [Optional]

Required only if you enable the Webcam plugin for quick mirror mode.

### Microphone [Optional]

Used by the Teleprompter plugin for mic-level monitoring during recording sessions.

### Notifications [Optional]

Allows the Notifications plugin to forward system alerts into the notch panel.

## Tips

- **Enable only what you use.** Each plugin is opt-in in Settings → Plugins. Start with Music and Calendar; add others as you go.
- **Multiple displays.** Enable "Show on all displays" in Settings → General to get the notch widget on external monitors too.
- **Keyboard shortcut.** Assign a global shortcut in Settings → Shortcuts to toggle the notch open/close without touching the mouse.
- **Hover delay.** If the notch opens too easily, increase the hover delay in Settings → General.
- **Local API.** Advanced users can drive mach.notch programmatically via the built-in HTTP server. See the [repo README](https://github.com/larsboes/mach-mono) for details.

## CTA

### Build a plugin

Every feature in mach.notch is a plugin. The same API is open to you.
[Plugin guide](https://github.com/larsboes/mach-mono/blob/main/docs/Guide.md#3-developer-guide-plugin-development)

---

## Developer Guide: Plugin Development

### Philosophy

**"Everything is a Plugin."**

Whether it's the core Music player or a simple Battery indicator, all features are built using the same API available to third-party developers. This ensures the API is robust and capable.

### Step-by-Step Implementation

#### 1. Create the Plugin Struct

Create a new file in `Packages/NotchPlugins/Sources/NotchPlugins/BuiltIn/{MyFeature}Plugin/`. It must conform to `NotchPlugin`.

```swift
import SwiftUI

@MainActor
@Observable
final class MyFeaturePlugin: NotchPlugin {
    // 1. Identity
    let id = "com.machnotch.myfeature"
    
    let metadata = PluginMetadata(
        name: "My Feature",
        description: "Does something amazing",
        icon: "star.fill", // SF Symbol
        category: .productivity
    )
    
    var isEnabled: Bool = true
    private(set) var state: PluginState = .inactive
    
    // 2. Dependencies
    private var settings: PluginSettings?
    private var cancellables = Set<AnyCancellable>()
    
    // 3. Lifecycle
    func activate(context: PluginContext) async throws {
        state = .activating
        self.settings = context.settings
        state = .active
    }
    
    func deactivate() async {
        state = .inactive
    }
}
```

#### 2. Define the UI

Plugins implement four UI slots via `@ViewBuilder` methods with concrete return types (no `AnyView`):

##### A. Closed Notch (Compact)

Shown inside the black notch bar. Space is limited.

```swift
@ViewBuilder
func closedNotchContent() -> some View {
    if isEnabled, state.isActive {
        HStack {
            Image(systemName: "star.fill")
            Text("Active")
        }
        .foregroundStyle(.white)
    } else {
        EmptyView()
    }
}
```

##### B. Expanded Panel (Interactive)

Shown when the user hovers/clicks the notch. This provides a full canvas.

```swift
@ViewBuilder
func expandedPanelContent() -> some View {
    if isEnabled, state.isActive {
        VStack {
            Text("My Amazing Feature")
                .font(.headline)
            Button("Do Action") { /* ... */ }
        }
        .padding()
    } else {
        EmptyView()
    }
}
```

##### C. Settings

Shown in the Settings panel for this plugin.

```swift
@ViewBuilder
func settingsContent() -> some View {
    Toggle("Show icon", isOn: $showIcon)
}
```

##### D. Menu Bar

Items contributed to the app's menu bar extra dropdown.

```swift
@ViewBuilder
func menuBarView() -> some View {
    Button("My Action") { /* ... */ }
}
```

#### 3. Requesting Display Time

The closed notch is a shared resource. Display must be **requested**.

Implement the `displayRequest` property:

```swift
var displayRequest: DisplayRequest? {
    guard isEnabled, state.isActive else { return nil }
    
    // logic: only show if something important is happening
    if myFeatureIsRunning {
        return DisplayRequest(
            priority: .normal, // .background, .normal, .high, .critical
            category: .utility
        )
    }
    
    return nil
}
```

#### 4. Accessing System Services

System APIs (like `EventKit` or `CoreAudio`) should **not** be accessed directly. Use the `PluginContext`.

```swift
func activate(context: PluginContext) async throws {
    // Get the shared calendar service
    let calendar = context.services.calendar
    
    // Get the shared music service
    let music = context.services.music
}
```

#### 5. Settings

Each plugin receives a sandboxed settings store.

```swift
func activate(context: PluginContext) async throws {
    self.settings = context.settings
    
    // Read
    let showIcon = settings?.get("showIcon", default: true)
}

func toggleIcon() {
    // Write
    settings?.set("showIcon", value: false)
}
```

### Testing Your Plugin

Testing is mandatory. Since the plugin is a class, it can be unit tested easily.

```swift
@MainActor
final class MyPluginTests: XCTestCase {
    func testActivation() async throws {
        let plugin = MyFeaturePlugin()
        
        // Use mocks!
        let context = PluginContext.mock()
        
        try await plugin.activate(context: context)
        
        XCTAssertEqual(plugin.state, .active)
    }
}
```

### Registration

Finally, add a descriptor to `PluginRegistry.swift` to register it. `AppObjectGraph` passes descriptors into `PluginManager`, and the plugin instance is constructed only when it is enabled, displayed, configured, exported, or otherwise explicitly requested.

```swift
// Packages/NotchPlugins/Sources/NotchPlugins/Core/PluginRegistry.swift
@MainActor
enum PluginRegistry {
    static func makeBuiltInDescriptors() -> [PluginDescriptor] {
        [
            PluginDescriptor(
                id: PluginID.myFeature,
                metadata: PluginMetadata(
                    name: "My Feature",
                    description: "A concise feature description.",
                    icon: "sparkles",
                    category: .utilities
                ),
                capabilities: [.settingsContent, .expandedPanelContent],
                factory: { MyFeaturePlugin() }
            )
        ]
    }
}
```

---

## Developer CLI Tooling: Bazel & Task Map

The `mach-mono` repository uses **Bazel** (`bazelisk`) as the canonical build system, but we provide **Task** (`Taskfile.yml`) as a thin wrapper for the most common operations to save keystrokes.

### Core Equivalents

| Action | Task Command | Underlying Bazel Command | Notes |
| :--- | :--- | :--- | :--- |
| **Build & Run mach.notch** | `task run` | `bazelisk build //Apps/machNotch:machNotch` | `task run` also unzips, signs, installs to `~/Applications`, and launches the app. |
| **Build mach.notch (no install)** | `task build` | `bazelisk build //Apps/machNotch:machNotch` | Just compiles the app bundle. |
| **Test mach.notch** | `task notch:test` | `bazelisk test //Packages/NotchPlugins:NotchPluginsTests` | Runs only notch tests. |
| **Build & Run mach.brief** | `task brief:run` | `bazelisk build //Apps/machBrief:machBrief` | Installs to `~/Applications` and launches. |
| **Test mach.brief** | `task brief:test` | `bazelisk test //Packages/MachBriefKit:MachBriefKitTests` | Runs only brief tests. |
| **Test All** | `task test` | `bazelisk test //Packages/NotchPlugins:NotchPluginsTests //Packages/MachBriefKit:MachBriefKitTests` | Runs all tests in the workspace. |

### Why Bazel?

We use Bazel for hermetic, caching, and reproducible builds across the monorepo. Xcode is used for **code navigation only**, meaning you shouldn't use Xcode's "Build" or "Run" buttons.

### Working with Bazel Directly

If you need to query the build graph or clear the cache, you can interact with Bazel directly:

- **Clean the cache:** `bazelisk clean --expunge`
- **Query targets:** `bazelisk query //...`

---

## Operations: iOS Sideloading (Free Developer Account Setup)

How to install mach.brief (or any app in this repo) on your own iPhone without paying $99/yr.

### What you need

- A Mac with Xcode installed
- A free Apple ID (your existing one works)
- An iPhone or iPad connected via USB (first time only)

### One-time setup

#### 1. Add your Apple ID to Xcode

`Xcode → Settings → Accounts → + → Apple ID`

Sign in with your Apple ID. Xcode creates a free "Personal Team" automatically.

#### 2. Trust the developer on your iPhone

After first install, iOS will block the app:  
`Settings → General → VPN & Device Management → [your Apple ID] → Trust`

Do this once. Subsequent installs from the same Apple ID don't require it again.

### Installing / updating

1. Open `mach-mono.xcworkspace` in Xcode
2. Select the `machBrief` scheme
3. Plug in your iPhone (or select it wirelessly after first pairing)
4. Hit **Run** (▶)

Xcode builds, signs, and installs in ~30 seconds.

### The 7-day expiry problem

Free Apple ID certificates expire after **7 days**. The app will refuse to launch until re-signed.

**Fix:** Plug in, hit Run in Xcode again. Takes 30 seconds.

**Automate it with AltStore (recommended):**

[AltStore](https://altstore.io) installs a small server on your Mac and refreshes your apps over WiFi automatically, so you never think about the 7-day limit.

Setup:

1. Download AltServer (Mac app) from altstore.io
2. Install AltStore onto your iPhone via AltServer
3. Open AltStore on your iPhone → My Apps → refresh machBrief
4. (Optional) Enable background refresh so AltStore does this automatically

**SideStore** is an alternative that works without a Mac running — it self-refreshes over a VPN loopback. More complex to set up, but fully autonomous.

### Adding widgets

After installing:

1. Long-press home screen → + (top left)
2. Search "mach.brief"
3. Add lock screen widget: swipe to lock screen → long-press → Customize → add widget
4. Add home screen widget: same + flow, choose medium size

Widgets populate automatically at the next scheduled word slot (6am, 12pm, 6pm, 12am).

### When you want to share with others

You'll need a paid Apple Developer account ($99/yr) to use TestFlight. With that:

1. Archive the app in Xcode (`Product → Archive`)
2. Upload to App Store Connect
3. Create a TestFlight build
4. Share the public TestFlight link — anyone can install, no device registration needed

### Troubleshooting

| Problem | Fix |
|---------|-----|
| "Untrusted Developer" on iPhone | Settings → General → VPN & Device Management → Trust |
| App won't launch after 7 days | Run from Xcode to re-sign |
| Xcode can't find device | Trust computer prompt on iPhone, unplug/replug |
| Build fails — signing error | Xcode → project settings → Signing → select your Personal Team |

---

## Operations: Release Runbook

How to cut a release of mach.notch from tag to published GitHub release.

### Secrets Setup

All of the following GitHub repository secrets must be set before the first release:

| Secret | What it is | How to generate |
|--------|-----------|-----------------|
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded `.p12` Apple Development certificate | Export from Keychain → base64 encode |
| `P12_PASSWORD` | Password protecting the `.p12` file | Set when exporting from Keychain |
| `KEYCHAIN_PASSWORD` | Temporary CI keychain password | Any random string |
| `PRIVATE_SPARKLE_KEY` | Sparkle EdDSA private key for signing the appcast | See below |

#### Generating the Sparkle EdDSA key (one-time setup)

```sh
# From the repo root — generates a key pair in the Sparkle tool directory
Apps/machNotch/Configuration/sparkle/generate_keys
```

The tool prints both keys:

- **Public key** → paste into `Apps/machNotch/machNotch/Info.plist` under `SUPublicEDKey`
- **Private key** → store as the `PRIVATE_SPARKLE_KEY` GitHub Actions secret (never commit this)

The public key is already in the repo. Only run `generate_keys` if you need to rotate.

### Release Process

#### 1. Verify the build is green

Ensure the latest commit on `main` passes CI (`cicd.yml` — build + test jobs).

#### 2. Update CHANGELOG.md

Add a new versioned section at the top of the file, above the current latest entry:

```markdown
## v1.4.0 — YYYY-MM-DD

### ✨ New features
- ...

### 🐛 Bug fixes
- ...
```

Commit directly to `main`: `git commit -m "chore: prep release v1.4.0"`.

#### 3. Push the tag

Tag format is `v<semver>` — examples: `v0.2.0`, `v0.2.0-beta.1`.

```sh
# Example
git tag v1.4.0
git push origin v1.4.0
```

Beta/RC tags (containing `beta` or `rc`) are automatically published as pre-releases.

#### 4. Watch the release pipeline

`release.yml` triggers on the tag push and runs three jobs in sequence:

1. **Preparation** — extracts version and build number from the tag
2. **Build and sign** (`build_reusable.yml`) — Bazel build → codesign → DMG
3. **Publish** — generates signed Sparkle appcast → commits `appcast.xml` to `main` → creates GitHub release with DMG attached

The publish job also refreshes the bug report issue-form version dropdown on `main` before creating the GitHub release.

#### 5. Verify the release

After the pipeline completes:

- GitHub release exists with the correct tag and DMG attached
- `Apps/machNotch/updater/appcast.xml` in `main` has the new version entry
- `.github/ISSUE_TEMPLATE/1-bug-report-form.yml` in `main` includes the new version in the dropdown
- Sparkle update check from an installed app picks up the new release

### Signing Notes

The app is signed with an **Apple Development** certificate, not a Developer ID. Users who download the DMG from GitHub Releases must bypass Gatekeeper once on first install:

```
Right-click app → Open → Open
# or
xattr -dr com.apple.quarantine /Applications/machNotch.app
```

Subsequent updates via Sparkle are automatic and do not require this step.

### Troubleshooting

- **Appcast push fails**: The `git push origin main` in the publish job can fail if `main` advanced since the tag was cut. The pipeline runs `git pull --rebase origin main` before committing. If it fails, rerun the publish job.
- **DMG not attached to release**: Rerun the build job.
- **Sparkle rejects the update**: The `PRIVATE_SPARKLE_KEY` secret does not match the `SUPublicEDKey` in Info.plist. Regenerate the key pair and update both.

---

## Documentation & CI/CD Pipeline

The public site at `https://larsboes.github.io/mach-mono` is a [Starlight](https://starlight.astro.build) (Astro) documentation site.

### Site Location

`website/` — Starlight site source.

### Building Locally

```sh
cd website
bun install
bun run build   # output: website/dist/
bun run dev     # dev server at http://localhost:4321
```

### CI Deployment

`.github/workflows/static.yml` builds and deploys the site on every push to `main`:

1. `bun install` in `website/`
2. `bun run build` — Astro/Starlight compiles to `website/dist/`
3. `actions/deploy-pages` publishes to GitHub Pages

### Content Mappings

- **Getting started**: `docs/Guide.md` (imported via MDX) → `/mach-mono/guide`
- **Changelog**: `CHANGELOG.md` (imported via MDX) → `/mach-mono/changelog`
- **Roadmap**: `docs/Roadmap.md` (imported via MDX) → `/mach-mono/roadmap`
- **Architecture**: `docs/Architecture.md` (imported via MDX) → `/mach-mono/architecture`

### Sparkle Appcast

`Apps/machNotch/updater/appcast.xml` is the Sparkle update feed. It is **not** part of the Starlight site. It is generated by the release pipeline (`release.yml`) and committed to `main` after each release.
