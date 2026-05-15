---
title: Getting started
subtitle: From build to first hover in under 2 minutes.
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
[Plugin guide](https://github.com/larsboes/mach-mono/blob/main/docs/guides/plugin-development.md)
