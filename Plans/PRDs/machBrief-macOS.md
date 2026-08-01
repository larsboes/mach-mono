---
id: machBrief-macOS
product: machBrief
display_name: mach.brief
platform: macOS
status: in_development
owner: larsboes
source_of_truth: true
related:
  app: Apps/machBrief
  package: Packages/MachBriefKit
  implementation_plan: Plans/PLAN-machBrief.md
  ios_prd: Plans/PRDs/machBrief-iOS.md
license:
  target: MIT
---

# mach.brief — PRD (macOS)

**Goal:** A configurable daily content feed for macOS. 4 slots per day (6am · 12pm · 6pm · 12am), each delivering one piece of content from the user's enabled sources. Surfaces via Menu Bar popover and Notification Center widget. Works completely standalone — Obsidian recommended as a data sink for power users.

**Platform:** macOS 26+ (primary). iOS v2. Android v3 (Kotlin reimplementation).

**Repo:** `Apps/machBrief/` inside mach-mono. Shared logic in `Packages/MachBriefKit/`.

**Implementation state (2026-06-13):** `Apps/machBrief` and
`Packages/MachBriefKit` both exist. The app has SwiftUI Today/Archive/Settings
surfaces, SwiftData storage, and a WidgetKit target. `MachBriefKit` owns
sources, sinks, scheduling, settings, resources, and tests. Implementation order
is tracked in `Plans/PLAN-machBrief.md`.

---

## Core Experience

4 slots per day at fixed intervals. Each slot reveals one entry from the user's active sources — a word, a fact, a quote, a mantra, or a mood check-in prompt. Content accumulates in an archive. The Notification Center widget and Menu Bar popover are the primary surfaces.

No streaks, no scoring, no pressure. Ambient enrichment.

---

## Non-Goals (v1 macOS)

- No iOS or Android (v2/v3)
- No user accounts or cloud sync
- No AI-generated content (v2 — Mood AI)
- No social features
- No custom slot times (v2)
- No audio (v2)
- No onboarding beyond source selection + widget setup prompt

---

## Platform Roadmap

| Phase | Platform | Notes |
|-------|----------|-------|
| v1 | macOS 26+ | Menu Bar + Notification Center widget — this PRD |
| v2 | iOS 18+ | Lock Screen + Home Screen widgets — see `Plans/PRDs/machBrief-iOS.md` |
| v3 | Android | Full Kotlin/Compose reimplementation of sources/sinks model — MachBriefKit does NOT port to Android |

---

## Architecture — Sources & Sinks

Every content type is a `BriefSource`. Every integration is a `BriefSink`. Both are opt-in and additive.

```
BriefSource (produces content)        BriefSink (receives events)
├── WordSource       — vocabulary     ├── ObsidianSink  — appends to daily note
├── FactSource       — trivia facts   ├── NotificationSink — system notification at slot time
├── QuoteSource      — daily quotes   └── (HealthKitSink — mood, iOS v2 only)
├── MantraSource     — mantras
└── MoodCheckInSource — prompted check-in

DailyScheduler
└── 4 slots/day — assigns sources to slots based on user config
```

**MachBriefKit** (`Packages/MachBriefKit/`) is a Swift package built primarily through Bazel for macOS 26. On Android, the sources/sinks model will be reimplemented in Kotlin/Compose — MachBriefKit is Swift-only.

---

## macOS Surfaces

### Menu Bar App

- Menu Bar icon (SF Symbol: `sun.horizon.fill` or `text.book.closed`) shows current slot source icon
- Click → popover opens with current slot card (source-appropriate layout)
- Popover tabs: **Today** · **Archive** · **Settings**
- `MenuBarExtra` scene (SwiftUI)
- App has no Dock icon (`LSUIElement = YES` in Info.plist)

### Notification Center Widget (WidgetKit)

- **Small widget:** Current slot title + subtitle. Updates at each slot via `TimelineProvider` with 4 entries/day.
- **Medium widget:** Full entry card — title, subtitle, body snippet.
- Tapping widget opens Menu Bar popover (via deep link URL scheme `machbrief://open`)
- macOS WidgetKit is available on macOS 26+ — no iOS required

### System Notification (NotificationSink)

- `UNUserNotificationCenter` fires at each slot time
- Short notification: source name + title
- Tapping notification opens Menu Bar popover

---

## Features — v1 macOS MVP

### Today View (Menu Bar Popover)

- Current slot card — layout adapts per source (word card, quote card, mood prompt)
- Slot indicator: which of the 4 daily slots is active
- Favorite button on each entry

### Archive (Popover Tab)

- Past entries newest-first
- Filterable by source
- Searchable by title/body text

### Settings (Popover Tab)

- Toggle each source on/off
- Configure slot assignment per source
- Obsidian vault path picker + test write button
- Notification permission toggle
- Widget setup nudge (links to System Settings → Widgets)

### machNotch Plugin (Optional)

- `MachBriefKit` linked as Bazel dependency in machNotch
- `closedNotchContent` — source icon + title snippet (right-aligned, yields to music)
- `expandedPanelContent` — full entry card with source-appropriate layout

---

## Content Sources — v1

### WordSource

- Bundled list: ~5,000 curated English words (public domain JSON)
- API enrichment: `GET https://api.dictionaryapi.dev/api/v2/entries/en/{word}` (no key, free)
- Returns: definition, part of speech, phonetics, example sentence
- Fallback: bundled definition if API unavailable

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
- Short, one-line phrases
- No API dependency

### MoodCheckInSource

- Prompt: "How are you feeling?" with 5 options: Awesome / Good / Okay / Bad / Terrible
- Optional one-line note after selection
- Writes to `BriefStore` (SwiftData)
- If ObsidianSink enabled: appends mood entry to daily note
- Scheduled for evening slot by default

---

## Integrations — Sinks

### ObsidianSink

Appends each slot entry to the user's Obsidian daily note as clean markdown.

**Setup:** User selects vault path in settings. Security-scoped bookmark persists across relaunches.

**Output format:**

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

**Failure handling:** Write failure is silent (logged internally).

### NotificationSink

- `UNUserNotificationCenter` fires at each slot boundary
- macOS system notification with source + title
- Permission requested on first launch

---

## Data Model

```swift
protocol BriefSource: Sendable {
    var id: String { get }
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
    let title: String
    let subtitle: String?
    let body: String?
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

## Repo Structure

```
mach-mono/
├── Apps/
│   └── machBrief/
│       ├── machBrief/              # macOS app source (MenuBarExtra)
│       ├── machBriefWidget/        # WidgetKit extension (macOS Notification Center)
│       └── BUILD.bazel             # Bazel build targets (canonical)
├── Packages/
│   └── MachBriefKit/               # Shared Swift package, Bazel-first
│       ├── Sources/MachBriefKit/
│       │   ├── Scheduler/
│       │   ├── Sources/
│       │   ├── Sinks/
│       │   ├── Store/
│       │   ├── API/
│       │   └── Models/
│       └── Resources/
│           ├── words.json
│           ├── facts.json
│           ├── quotes.json
│           └── mantras.json
└── Apps/
    └── machNotch/
        └── Plugins/BuiltIn/BriefPlugin/   # optional machNotch integration
```

**Bazel build/test:** `bazel build //Apps/machBrief:machBrief` and `bazel test //Packages/MachBriefKit:MachBriefKitTests` are the canonical verification commands. Xcode project files are optional IDE scaffolding.

---

## Distribution

| Phase | Method | Cost |
|-------|--------|------|
| Development | Xcode → local Mac (free Apple ID) | $0 |
| Personal use | Notarized .dmg, direct install | $0 with paid dev account |
| Public beta | GitHub Releases — notarized .dmg | $99/yr (developer account) |
| App Store | Mac App Store | $99/yr |

---

## Tech Stack

- **Language:** Swift 6.3
- **UI:** SwiftUI
- **App shell:** `MenuBarExtra` — no Dock icon
- **Persistence:** SwiftData (macOS 26+)
- **Widgets:** WidgetKit (macOS 26+)
- **Networking:** URLSession — WordSource API enrichment only
- **Shared logic:** `MachBriefKit` local Swift package, built through Bazel
- **Min macOS:** 26.0

---

## License

MIT — clean slate. No GPL or MPL dependencies.

All bundled JSON content must be public domain or CC0 before ship:

- `words.json` — english-words (public domain) + manual curation
- `facts.json` — hand-written originals or CC0 sources only
- `quotes.json` — pre-1928 authors only OR original paraphrases
- `mantras.json` — original compositions inspired by loving kindness tradition

---

## v2 Ideas

- iOS support — see `Plans/PRDs/machBrief-iOS.md`
- Mood AI — pattern recognition, trigger tracking
- HealthKit sink for mood data (iOS only)
- Custom slot times
- iCloud sync for favorites and mood history
- Audio pronunciation for WordSource
- Share card (share sheet with entry image)
- macOS menu bar badge showing current slot number
- Additional sources: calendar preview, weather summary
