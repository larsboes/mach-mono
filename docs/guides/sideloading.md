# iOS Sideloading — Free Developer Account Setup

How to install mach.brief (or any app in this repo) on your own iPhone without paying $99/yr.

---

## What you need

- A Mac with Xcode installed
- A free Apple ID (your existing one works)
- An iPhone or iPad connected via USB (first time only)

---

## One-time setup

### 1. Add your Apple ID to Xcode

`Xcode → Settings → Accounts → + → Apple ID`

Sign in with your Apple ID. Xcode creates a free "Personal Team" automatically.

### 2. Trust the developer on your iPhone

After first install, iOS will block the app:  
`Settings → General → VPN & Device Management → [your Apple ID] → Trust`

Do this once. Subsequent installs from the same Apple ID don't require it again.

---

## Installing / updating

1. Open `mach-mono.xcworkspace` in Xcode
2. Select the `machBrief` scheme
3. Plug in your iPhone (or select it wirelessly after first pairing)
4. Hit **Run** (▶)

Xcode builds, signs, and installs in ~30 seconds.

---

## The 7-day expiry problem

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

---

## Adding widgets

After installing:

1. Long-press home screen → + (top left)
2. Search "mach.brief"
3. Add lock screen widget: swipe to lock screen → long-press → Customize → add widget
4. Add home screen widget: same + flow, choose medium size

Widgets populate automatically at the next scheduled word slot (6am, 12pm, 6pm, 12am).

---

## When you want to share with others

You'll need a paid Apple Developer account ($99/yr) to use TestFlight. With that:

1. Archive the app in Xcode (`Product → Archive`)
2. Upload to App Store Connect
3. Create a TestFlight build
4. Share the public TestFlight link — anyone can install, no device registration needed

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Untrusted Developer" on iPhone | Settings → General → VPN & Device Management → Trust |
| App won't launch after 7 days | Run from Xcode to re-sign |
| Xcode can't find device | Trust computer prompt on iPhone, unplug/replug |
| Build fails — signing error | Xcode → project settings → Signing → select your Personal Team |
