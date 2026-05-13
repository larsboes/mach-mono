# Markdown → HTML pipeline

`Apps/machNotch/updater/build.py` converts Markdown source files into the HTML pages served on GitHub Pages. It uses Python 3 stdlib only — no pip, no external tools.

## Source → output mapping

| Source | Output | Builder |
|--------|--------|---------|
| `CHANGELOG.md` | `updater/changelog.html` | `build_changelog()` |
| `ROADMAP.md` | `updater/roadmap.html` | `build_roadmap()` |
| `GUIDE.md` | `updater/guide.html` | `build_guide()` |

All three outputs are assembled from a shared shell: `updater/_template.html`.

## Running the build

**Standalone** (from any directory):

```sh
python3 Apps/machNotch/updater/build.py
```

Paths are resolved relative to the script file, so it works from any working directory.

**Via Bazel** (hermetic, sandboxed):

```sh
bazel build //Apps/machNotch/updater:site
```

Outputs land in `bazel-bin/Apps/machNotch/updater/`.

**Custom paths** (useful in CI):

```sh
python3 Apps/machNotch/updater/build.py \
  --changelog path/to/CHANGELOG.md \
  --roadmap   path/to/ROADMAP.md \
  --guide     path/to/GUIDE.md \
  --template  path/to/_template.html \
  --outdir    dist/
```

## Template placeholders

`_template.html` contains four string tokens that `build.py` replaces at render time:

| Placeholder | Replaced with |
|-------------|---------------|
| `{{TITLE}}` | `<title>` content (e.g. `Changelog — mach`) |
| `{{PAGE_STYLE}}` | Page-specific CSS injected into a `<style>` block |
| `{{NAV_ITEMS}}` | `<li>` elements for the top nav; active page gets `class="active"` |
| `{{CONTENT}}` | The full page body HTML |

## Markdown formats

### CHANGELOG.md — Keep a Changelog

```markdown
# Changelog

## Pre-release

### 🐛 Bug fixes
- **Component name**: what changed and why.

## [0.1.0] — 2026-01-01

### ✨ New features
- **Feature name**: description.
```

- `## Heading` with an ISO date becomes a released version; without a date it's "Unreleased".
- `### Heading` is a change section (Bug fixes, New features, etc.). The dot colour in the rendered card is determined by keywords in the heading (bug/fix → red, feat → purple, ui → blue, etc.).
- `#### Sub-heading` adds a named sub-group within a section.
- List items: `- **Name**: description` (bolded leader + description) or bare `- description`.

### ROADMAP.md — section/card format

```markdown
---
subtitle: One-line description shown under the "Roadmap" heading.
---

## ↑ In progress

### Card title [Tag]
Short description of the card.

## ⌛ Planned

### Another card
Description.

## 🚀 Launched

_Nothing launched yet._
```

- Front matter: only `subtitle` is used.
- `## Icon Title` — the leading character sets the section kind: `↑` → active (green), `⌛` → planned (orange), `🚀` → launched (blue).
- `### Title [Tag]` — the optional `[Tag]` token becomes a label badge on the card.
- Italic-only line `_text_` when a section has no cards → rendered as an empty-state placeholder.

### GUIDE.md — section/item format

```markdown
---
title: Getting started
subtitle: From download to first hover in under 2 minutes.
---

## Installation

### Step title
Step description. Markdown inline elements (`code`, **bold**, [links](url)) are supported.

## Permissions

### Permission name [Required]
What this permission is used for.

### Another permission [Optional]
Description.

## Tips

- **Bold lead.** Rest of tip text.
- Another tip without a bold lead.

## CTA

### Section heading
One-line description.
[Button label](https://link-url)
```

- Front matter: `title` (page `<h1>`), `subtitle` (subtitle paragraph).
- `## Installation` → numbered steps. Each `### Heading` becomes one step; body text is the step description.
- `## Permissions` → permission grid. `### Name [Required]` or `### Name [Optional]` sets the badge; body is the description. Permissions without a tag default to Optional.
- `## Tips` → tip list. Each `- item` becomes one tip card.
- `## CTA` → action strip at the bottom. First `### Heading` is the CTA title; body text is the description; a bare `[label](url)` line on its own becomes the button.

## Adding a new page

1. Create a Markdown source file at the repo root (e.g. `FAQ.md`).
2. Add a parser function `parse_faq(md: str) -> ...` in `build.py`.
3. Add a CSS constant `FAQ_CSS` and a renderer `render_faq_content(...)`.
4. Add a `build_faq(*, faq_path, template_path, out_path)` function following the same pattern as `build_changelog` / `build_guide`.
5. Add `--faq` to `main()`'s `argparse` block and call `build_faq()`.
6. Add the new entry to `NAV_PAGES` if it should appear in the nav.
7. In `BUILD.bazel` (updater rule): add `//:FAQ.md` to `srcs`, `faq.html` to `outs`, and `--faq $(location //:FAQ.md)` to `cmd`.
8. In the root `BUILD.bazel`: add `"FAQ.md"` to `exports_files([...])`.
