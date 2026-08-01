---
id: machBrief-iOS
product: machBrief
display_name: mach.brief
platform: iOS
status: planned
owner: larsboes
source_of_truth: true
related:
  app: Apps/machBrief
  package: Packages/MachBriefKit
  macos_prd: Plans/PRDs/machBrief-macOS.md
  implementation_plan: Plans/PLAN-machBrief.md
license:
  target: MIT
---

# mach.brief — PRD (iOS — v2, planned after macOS)

> **Status:** Future / planned. macOS is v1 — see `Plans/PRDs/machBrief-macOS.md`. This document defines the iOS implementation to follow.

> **Implementation note (2026-06-13):** Shared source/sink logic already lives in
> `Packages/MachBriefKit`; iOS remains v2 and follows the macOS v1 work tracked
> in `Plans/PLAN-machBrief.md`.

**Goal:** A configurable daily content feed for iOS. 4 slots per day (6am · 12pm · 6pm · 12am), each delivering one piece of content from the user's enabled sources. Lock Screen widget is the primary surface. Works completely standalone — Obsidian recommended as a data sink for power users.

**Repo:** `Apps/machBrief/` inside mach-mono. Shared logic in `Packages/MachBriefKit/`.

---

## Core Experience

4 slots per day at fixed intervals. Each slot reveals one entry from the user's active sources — a word, a fact, a quote, a mantra, or a mood check-in prompt. Content accumulates in an archive. The lock screen widget is the primary surface.

No streaks, no scoring, no pressure. Ambient enrichment.

---

## Non-Goals (v1)

- No user accounts or cloud sync
- No AI-generated content (v2 — Mood AI)
- No social features
- No custom slot times (v2)
- No audio (v2)
- No onboarding beyond source selection + widget setup prompt

---

## Architecture — Sources & Sinks

Every content type is a `BriefSource`. Every integration is a `BriefSink`. Both are opt-in and additive — nothing breaks when you add or remove one.

```
BriefSource (produces content)        BriefSink (receives events)
├── WordSource       — vocabulary     ├── ObsidianSink  — appends to daily note
├── FactSource       — trivia facts   ├── HealthKitSink — mood → HK (v2)
├── QuoteSource      — daily quotes   └── NotificationSink — push at slot time
├── MantraSource     — mantras
└── MoodCheckInSource — prompted check-in

DailyScheduler
└── 4 slots/day — assigns sources to slots based on user config
```

---

## Content Sources — v1

### WordSource

- Bundled list: ~5,000 curated English words (public domain JSON)
- API enrichment: `GET https://api.dictionaryapi.dev/api/v2/entries/en/{word}` (no key, free)
- Returns: definition, part of speech, phonetics, example sentence
- Fallback: bundled definition if API unavailable
- Word list: [english-words](https://github.com/dwyl/english-words) filtered to 4–12 letters, no proper nouns

### FactSource

- Bundled list: ~1,000 curated trivia facts (JSON, hand-curated)
- Categories: science, history, nature, language, culture
- No API dependency — fully offline

### QuoteSource

- Bundled list: ~500 curated motivational/philosophical quotes (JSON)
- Format: quote text + author
- No API dependency

### MantraSource

- Bundled list: ~100 loving kindness / mindfulness mantras (JSON)
- Short, one-line phrases — designed for lock screen
- No API dependency

### MoodCheckInSource

- Prompt: "How are you feeling?" with 5 options: Awesome / Good / Okay / Bad / Terrible
- Optional one-line note after selection
- Writes to `BriefStore` (SwiftData)
- If ObsidianSink enabled: appends mood entry to daily note
- Scheduled for evening slot by default (configurable)

---

## Integrations — Sinks

### ObsidianSink (Recommended)

The flagship integration. Appends each slot entry to the user's Obsidian daily note as clean markdown. User owns all data — no API, no plugin required in Obsidian.

**Setup:** User selects vault path in settings. mach.brief gets file access via security-scoped bookmark (persists across relaunches without re-prompting).

**Output format (configurable template):**

```markdown
## Daily Brief — 12:00

**Word:** smellfungus
*(n.) A person who complains excessively*
> "Don't be such a smellfungus."

---
```

**Mood entry format:**

```markdown
## Mood — 18:00
Feeling: Good
Note: productive afternoon, good focus session
```

**Failure handling:** Write failure is silent (logged internally) — never interrupts the user experience.

---

## Data Model

```swift
protocol BriefSource: Sendable {
    var id: String { get }          // "word", "fact", "quote", "mantra", "mood"
    var displayName: String { get }
    func entry(for slot: DailySlot, date: Date) async -> BriefEntry
}

protocol BriefSink: Sendable {
    func receive(_ entry: BriefEntry) async
}

struct BriefEntry: Codable, Identifiable {
    let id: UUID
    let sourceID: String
    let slot: DailySlot
    let title: String           // main content
    let subtitle: String?       // author, part of speech, phonetic
    let body: String?           // definition, full quote, example sentence
    let metadata: [String: String]
    var isFavorited: Bool
    let revealedAt: Date
}

enum DailySlot: Int, CaseIterable, Codable {
    case morning   = 0  // 6am
    case midday    = 1  // 12pm
    case afternoon = 2  // 6pm
    case evening   = 3  // 12am
}
```

---

## Features — v1 MVP

### iOS App (machBrief)

- **Today view:** Current slot card — layout adapts per source (word card, quote card, mood prompt)
- **Archive:** Past entries newest-first, filterable by source, searchable
- **Favorites:** Bookmarked entries across all sources
- **Source settings:** Toggle each source on/off, configure slot assignment
- **Obsidian setup:** Vault path picker, template preview, test write button
- **Widget setup prompt:** First-launch nudge

### Widgets (WidgetKit)

- **Lock screen widget:** Title + subtitle of current slot entry. Updates at each slot via `TimelineProvider` with 4 entries/day pre-loaded.
- **Home screen widget (medium):** Full entry card — title, subtitle, body snippet.
- **Interactive widget (iOS 17+):** Mood check-in tappable directly from lock/home screen — no app open required.

### machNotch Plugin (macOS)

- `MachBriefKit` linked as Bazel dependency in machNotch
- `closedNotchContent` — source icon + title snippet (right-aligned, yields to music)
- `expandedPanelContent` — full entry card with source-appropriate layout
- Same `DailyScheduler` deterministic logic — same slot content as iOS

---

## Repo Structure

```
mach-mono/
├── Apps/
│   └── machBrief/
│       ├── machBrief/           # iOS app source
│       ├── machBriefWidget/     # WidgetKit extension
│       └── BUILD.bazel          # Bazel build targets (canonical)
├── Packages/
│   └── MachBriefKit/            # Shared Bazel-built Swift package (macOS + iOS)
│       ├── Sources/MachBriefKit/
│       │   ├── Scheduler/
│       │   │   ├── DailyScheduler.swift
│       │   │   └── DailySlot.swift
│       │   ├── Sources/
│       │   │   ├── BriefSource.swift        # protocol
│       │   │   ├── WordSource.swift
│       │   │   ├── FactSource.swift
│       │   │   ├── QuoteSource.swift
│       │   │   ├── MantraSource.swift
│       │   │   └── MoodCheckInSource.swift
│       │   ├── Sinks/
│       │   │   ├── BriefSink.swift          # protocol
│       │   │   ├── ObsidianSink.swift
│       │   │   └── NotificationSink.swift
│       │   ├── Store/
│       │   │   └── BriefStore.swift         # SwiftData persistence
│       │   ├── API/
│       │   │   └── DictionaryAPIClient.swift
│       │   └── Models/
│       │       └── BriefEntry.swift
│       └── Resources/
│           ├── words.json
│           ├── facts.json
│           ├── quotes.json
│           └── mantras.json
└── Apps/
    └── machNotch/
        └── Plugins/BuiltIn/BriefPlugin/
```

---

## Distribution

| Phase | Method | Cost |
|-------|--------|------|
| Development | Xcode → iPhone (free Apple ID) | $0 |
| Personal beta | Re-sign every 7 days or AltStore | $0 |
| Public beta | TestFlight | $99/yr |
| App Store | App Store | $99/yr |

See `docs/Guide.md` for full setup guide.

---

## License & Reengineering Principle

**License:** MIT — clean slate, no inherited copyleft.

**Reengineering mandate:** mach.brief is inspired by commercial apps (Vocabulary - Learn words daily, Self Growth Essentials by Monkey Taps) and open-source projects. No code is copied. Every component is an original implementation of independently-arrived-at ideas. This is a design principle, not just a legal requirement — reengineering forces better architecture.

**Content licensing:** All bundled JSON content (`words.json`, `facts.json`, `quotes.json`, `mantras.json`) must be public domain or CC0 before ship. Sources:

- `words.json` — [english-words](https://github.com/dwyl/english-words) (public domain) + manual curation
- `facts.json` — hand-written originals or CC0 sources only (e.g. Wikipedia summaries rewritten)
- `quotes.json` — pre-1928 authors only (public domain) OR original paraphrases — NO post-1928 direct quotes
- `mantras.json` — original compositions inspired by loving kindness tradition (not copied from any app)

**machNotch plugins** that reimplement GPL-inspired functionality document their independence explicitly in the PRD. The same principle applies here.

---

## Tech Stack

- **Language:** Swift 6+
- **UI:** SwiftUI
- **Persistence:** SwiftData (iOS 20+ / macOS 26+)
- **Widgets:** WidgetKit + App Intents (interactive widgets)
- **Networking:** URLSession — WordSource API enrichment only
- **Shared logic:** `MachBriefKit` Bazel-built package
- **Min iOS:** 18.0 | **Min macOS:** 26.0

---

## v2 Ideas

- Mood AI — pattern recognition, trigger tracking, emotional trends
- Mood → Obsidian Dataview-compatible frontmatter
- HealthKit sink for mood data
- Custom slot times
- iCloud sync for favorites and mood history
- Audio pronunciation for WordSource
- Share card (share sheet with entry image)
- Notifications at slot times
- macOS Notification Centre widget
- Additional sources: calendar preview, weather summary
