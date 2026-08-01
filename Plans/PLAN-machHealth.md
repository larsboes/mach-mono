---
id: machhealth
status: draft
owner: larsboes
source_of_truth: true
related:
  consumer_1: Plans/PLAN-machSound.md   # machSound — first consumer, not the only one
  agent_guidelines: docs/AGENT-GUIDELINES.md
  license_policy: docs/decisions/0003-license-policy.md
  machbrief_ios_prd: Plans/PRDs/machBrief-iOS.md
last_updated: 2026-06-10
---

# machHealth — Open-Source HealthKit → Mac Exporter

**Goal:** A deliberately tiny, fully self-owned, open-source iOS app that exports
selected HealthKit metrics as versioned JSON to a self-built receiver on the local
network. No cloud, no broker, no third-party apps or SDKs — nothing to "rely on"
that can disappear. machSound is the first consumer; the schema is generic so any
future consumer (machBrief, CLI tools, future projects) can subscribe.

**Why it exists:** the Health store lives only on iPhone/Watch (verified 2026-06);
macOS cannot query it. Closed export apps exist but are rejected on principle:
this must be inspectable, forkable, and permanent.

**Shape:** `Apps/machHealth` (iOS, SwiftUI, minimal) + `Packages/HealthExportKit`
(all logic, app is a thin shell) + a small Mac receiver reference implementation
(later embedded in machSound's stack).

---

## 0. Non-Goals

- **No cloud, ever.** LAN-only transport. No analytics, no telemetry, no accounts.
- **No analysis in the app.** Export only. Derivations (baselines, arousal,
  sleep quality) happen on the consumer side — keeps the app dumb and stable.
- **No dashboards/visualization.** Consumers do that.
- **No HealthKit write-back.** Read-only, full stop.
- **No Watch app in v1.** iPhone-resident Health store is the source; live ~1Hz
  streaming is explicitly out of scope (minute-scale is the accepted granularity).
- **No third-party dependencies** in HealthExportKit core. URLSession, HealthKit,
  Network.framework, Foundation — that's it.

---

## 1. Data Contract (versioned, the most important artifact)

```json
{
  "schema": 1,
  "device": "lars-iphone",
  "sentAt": "2026-06-10T21:14:03+02:00",
  "samples": [
    { "uuid": "…", "type": "heartRate", "value": 61, "unit": "bpm",
      "start": "…", "end": "…", "source": "Apple Watch", "meta": {} },
    { "uuid": "…", "type": "sleepStage", "value": "deep", "unit": "stage",
      "start": "…", "end": "…" }
  ]
}
```

- **Metric set v1:** heartRate, hrvSDNN, restingHeartRate, sleepStage, steps,
  activeEnergy, workout (type/start/end), mindfulMinutes. Each individually
  toggleable in the app; default = all off (explicit opt-in per metric).
- Dedupe key: HealthKit sample UUID. Consumers must treat posts as
  at-least-once delivery.
- Schema changes bump `schema`; receiver rejects unknown majors loudly.

## 2. Architecture

**HealthExportKit (package, all logic, unit-testable):**
- `Authorizer` — HealthKit read authorization per selected metric.
- `IncrementalReader` — `HKAnchoredObjectQuery` per type with persisted anchors
  (incremental, no re-sends across launches).
- `BackgroundScheduler` — `HKObserverQuery` + `enableBackgroundDelivery`
  (honest note: iOS throttles wakeups per type; HR while not in workout syncs
  from Watch in batches. Minute-to-hour latency is the contract, not a bug).
- `Serializer` — schema v1 encoder.
- `Transport` — URLSession POST to receiver; persistent retry queue with
  exponential backoff (samples must survive app kills before delivery).
- `Discovery` — Bonjour browse for `_machhealth._tcp` receivers.
- `Pairing` — first-connect 6-digit code shown on Mac, exchanged for a token;
  token sent per-request (HMAC over body). TLS optional later; LAN + HMAC is the
  v1 floor.

**App (thin SwiftUI shell):** auth flow, metric toggles, receiver picker (Bonjour
list + manual host:port), pairing screen, status view (last sync, queue depth,
recent errors), manual "sync now". Nothing else. Design-system aesthetic.

**Mac receiver (reference impl):** Network.framework listener, Bonjour advertise,
pairing/token store, validates schema, hands samples to a delegate. Ships as part
of HealthExportKit (multi-platform package) so machSound embeds it directly.

## 3. Phases

### H0 — Shortcuts bridge + receiver stub (zero app code)
- Build the Mac receiver stub first (it's needed regardless).
- iOS Shortcuts personal automation: "Find Health Samples" → POST to the stub,
  time-triggered (~15-min granularity). Validates schema, mapping rules, and the
  whole machSound consumption path **before any app exists**.
- **Latency ground truth (H0's most important output):** log, for ≥1 week,
  the gap between sample `end` time and Mac arrival per metric type. This number
  — not hopes — defines what machSound's adaptation rules may assume. If reality
  is hourly rather than 15-min, the rules are designed for hourly. Publish the
  measured table into this plan before H1 starts.
- Exit: health-derived context visibly arriving on the Mac **+ latency table
  committed below.**

| Metric (H0 measured) | Median latency | p90 | Notes |
|---|---|---|---|
| heartRate | _tbd_ | _tbd_ | |
| hrvSDNN | _tbd_ | _tbd_ | |
| sleepStage | _tbd_ | _tbd_ | morning batch expected |
| restingHeartRate | _tbd_ | _tbd_ | daily |

### H1 — MVP app
- HealthExportKit: Authorizer, IncrementalReader, Serializer, Transport (no retry
  queue yet), Discovery, Pairing. App shell with metric toggles + status.
- Metrics: heartRate, hrvSDNN, restingHeartRate, sleepStage.
- Foreground sync + basic background delivery.
- Exit: replaces the Shortcuts bridge end-to-end for a full week without babysitting.

### H2 — Hardening
- Persistent retry queue + anchor persistence + at-least-once guarantees tested.
- Remaining v1 metrics (steps, activeEnergy, workout, mindfulMinutes).
- Baseline importer: Mac CLI parsing Apple Health `export.zip` (XML) to seed
  historical baselines (HRV trend, resting HR) — one-time, stable, no hacks.
- Battery audit on iPhone (background delivery cost must be negligible).

### H3 — Polish / community
- Multiple receivers, per-receiver metric sets.
- Distribution decision: personal sideload (free, 7-day re-sign pain) vs paid dev
  account TestFlight vs App Store. App Review note: health data must stay
  user-controlled and local — LAN-only export is defensible, but review risk is
  real; sideload/TestFlight is the safe default for a personal tool.
- README + schema docs good enough for strangers to adopt.

## 4. Risks & Honest Notes

- **Background delivery is the #1 disappointment risk.** iOS decides when you wake.
  That's why H0 measures real-world latency *before any app code exists* and
  commits the table above; machSound's adaptation rules are designed against the
  measured numbers, defaulting to "data may be 30–60 min stale" until proven better.
- **HealthKit entitlement requires a paid developer account** for distribution
  beyond personal sideload. Decide in H3, not before.
- **Privacy is the product.** One bad default (a metric on without opt-in, a log
  line with raw values) undermines the whole "self-owned" point. Logs redact
  values; pairing required; metrics default off.
- **Scope magnet:** people will ask for CSV export, charts, cloud sync, Android.
  The answer is the Non-Goals section.

## 5. Open Questions

1. Standalone `Apps/machHealth` vs module in machBrief iOS? (Recommendation:
   standalone app, shared HealthExportKit package — reusability and a clean
   single-purpose story. machBrief can consume the same package later.)
2. TLS on LAN (self-signed + pinning) in v1, or HMAC-token floor first? (Floor
   first; TLS in H2.)
3. Bazel: does the iOS app build join the Bazel graph immediately or start
   Xcode-only like early targets? (Follow repo convention.)
4. Name check: `machHealth` fits the family — any conflict with existing plans?

## 6. Immediate Next Steps

1. Receiver stub (Network.framework + Bonjour + token pairing) — also unblocks
   machSound M2 context testing with fake data.
2. Shortcuts automation posting to it (H0).
3. Schema v1 written down in `docs/` once it survives a week of H0 traffic.
