# UI/UX Showcase Plan

How to record a clean video + screenshot of mach.notch and ship them into README and the GitHub Pages landing page.

---

## 1. Prepare the environment

- Auto-hide the Dock: **System Settings → Desktop & Dock → Auto-hide**
- Auto-hide the menu bar: **System Settings → Control Centre → Automatically hide menu bar**
- Set a clean, dark wallpaper (no icons on Desktop)
- Quit all apps except machNotch
- Optional: enable Do Not Disturb to prevent notification interruptions

---

## 2. Record the video

**Option A — region capture (recommended)**

```bash
# Cmd+Shift+5 → drag to select just the notch area → Record Selected Portion
# OR use QuickTime:
open -a "QuickTime Player"
# New Screen Recording → drag region around the notch → click Record
```

- Uncheck **Show Mouse Cursor** unless demonstrating hover
- Use `tools/notchctl` to script a repeatable demo sequence:

```bash
tools/notchctl open
tools/notchctl music play-pause
tools/notchctl toggle
```

**Option B — gifski (animated GIF for universal embed)**

```bash
brew install gifski
gifski --fps 20 --width 700 input.mov -o docs/assets/notch-demo.gif
```

GIFs embed anywhere (GitHub, emails, Slack) but are larger. Use for a short loop (< 5 seconds).

---

## 3. Take the screenshot

```bash
# -x = no shutter sound, -o = open in Preview after
screencapture -xo docs/assets/notch-preview.png
```

Crop to the notch area in Preview or Pixelmator. Export as WebP for smaller size:

```bash
sips -s format webp docs/assets/notch-preview.png --out docs/assets/notch-preview.webp
```

Commit the asset:

```bash
git add docs/assets/notch-preview.webp
git commit -m "assets: add notch UI screenshot"
```

---

## 4. Host the video via GitHub CDN

GitHub doesn't serve raw video from the repo well. Use the free GitHub CDN trick:

1. Open any issue in this repo on github.com
2. Drag the `.mp4` / `.mov` into the comment text area
3. Wait for the upload → GitHub generates a URL like:
   `https://github.com/user-attachments/assets/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
4. Copy the URL — **do not submit the issue**
5. Use the URL in README and index.html (see below)

---

## 5. Wire into README

Add a hero block near the top of `README.md`, below the title/badges:

```md
<video src="PASTE_CDN_URL_HERE" autoplay loop muted playsinline width="100%"></video>

![mach.notch UI](docs/assets/notch-preview.webp)
```

`autoplay loop muted` makes it play silently like a hero reel — no user interaction needed.

---

## 6. Wire into the GitHub Pages landing page

Edit `Apps/machNotch/updater/index.html` — add a hero media block between the `<header>` and the `.apps` grid:

```html
<div class="hero-media">
  <video src="PASTE_CDN_URL_HERE" autoplay loop muted playsinline></video>
  <!-- fallback image if video fails to load -->
  <img src="https://raw.githubusercontent.com/larsboes/mach-mono/main/docs/assets/notch-preview.webp" alt="mach.notch preview" />
</div>
```

Add matching CSS for `.hero-media` (max-width, border-radius, subtle border, margin-bottom).

---

## 7. Checklist

- [ ] Environment cleaned (Dock hidden, wallpaper set, no notifications)
- [ ] Video recorded (region-cropped to notch area)
- [ ] GIF or MP4 — pick one for README, both optional
- [ ] Screenshot captured → `docs/assets/notch-preview.webp`
- [ ] Video uploaded to GitHub CDN via Issue trick → CDN URL copied
- [ ] README updated with `<video>` tag + screenshot
- [ ] `index.html` updated with hero media block
- [ ] Everything committed and pushed → Pages redeploys automatically
