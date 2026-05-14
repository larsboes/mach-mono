---
title: Getting started
subtitle: From build to first hover in under 2 minutes.
---

## Installation

### Download the app [Recommended]
Download the latest `.dmg` from the [GitHub Releases page](https://github.com/larsboes/mach-mono/releases). Open the DMG, drag **mach.notch** to `/Applications`, then launch it.

**First launch:** macOS will block the app because it is not notarized by Apple. Right-click the app → **Open**, then click **Open** in the dialog. Or run once in Terminal:
```sh
xattr -dr com.apple.quarantine /Applications/machNotch.app
```
This is a one-time step. All future updates through the built-in updater are silent and automatic.

### Build from source

### Install Bazelisk
Run `brew install bazelisk`. You also need Xcode 16 or later installed (free from the App Store) — Bazel uses it as the Swift toolchain.

### Clone the repo
`git clone https://github.com/larsboes/mach-mono.git` then `cd mach-mono`.

### Build and launch
`bazelisk build //Apps/machNotch:machNotch` — the compiled app lands in `bazel-bin/Apps/machNotch/machNotch.app`. Open it directly or copy to `/Applications`.

### Grant Accessibility access
On first launch, macOS will ask for Accessibility permission — this is the only required permission. Click **Open System Settings**, find **mach.notch** in the list, and toggle it on. The app needs this to detect your cursor hovering over the notch and to intercept media keys.

### Hover to open
Move your cursor over the notch at the top of your screen — it expands. Move away and it closes. Open **Settings** (gear icon in the notch header, or from the menu bar icon) to enable plugins and customise behaviour.

## Permissions

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
