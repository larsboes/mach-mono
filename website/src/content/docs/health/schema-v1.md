---
title: Health Export Schema v1
description: The versioned LAN contract machHealth sends and machSound consumes.
---

machHealth exports HealthKit-derived samples to a Mac over the local network. This is the wire contract. It is versioned, and a receiver rejects a payload whose `schema` it does not recognise rather than guessing.

Defined in [`HealthExportSchema.swift`](https://github.com/larsboes/mach-mono/blob/main/Packages/HealthExportKit/Sources/HealthExportKit/HealthExportSchema.swift).

## Payload

```json
{
  "schema": 1,
  "device": "iPhone",
  "sentAt": "2026-08-30T14:22:31Z",
  "samples": [
    {
      "uuid": "8B1F2C4E-...",
      "type": "heartRate",
      "value": "62",
      "unit": "count/min",
      "start": "2026-08-30T14:21:00Z",
      "end": "2026-08-30T14:22:00Z",
      "source": "Apple Watch",
      "meta": {}
    }
  ]
}
```

| Field | Type | Notes |
| --- | --- | --- |
| `schema` | integer | Currently `1`. A receiver must reject anything else. |
| `device` | string | Human-readable origin, for display only. Not an identity claim. |
| `sentAt` | ISO 8601 | When the payload left the phone, not when the samples were recorded. |
| `samples` | array | May be empty; an empty payload is a valid heartbeat. |

## Sample

| Field | Type | Notes |
| --- | --- | --- |
| `uuid` | string | The HealthKit sample UUID. **Deduplicate on this** — see delivery below. |
| `type` | string | One of the metric types listed below. |
| `value` | string | Carried as a string so no precision is lost in JSON number handling. |
| `unit` | string | HealthKit unit string, e.g. `count/min`, `ms`, `kcal`. |
| `start`, `end` | ISO 8601 | Sample interval. Equal for instantaneous readings. |
| `source` | string, optional | Recording device or app, when HealthKit reports one. |
| `meta` | object | String-to-string. Type-specific extras; may be empty. |

## Metric types

`heartRate`, `hrvSDNN`, `restingHeartRate`, `sleepStage`, `steps`, `activeEnergy`, `workout`, `mindfulMinutes`.

An unknown type is a schema change and requires a version bump.

## Encoding

JSON with ISO 8601 dates and sorted keys, so a payload is byte-stable for a given input and can be diffed or hashed. `HealthExportSerializer` is the only supported encoder and decoder; it validates `schema` in both directions.

## Pairing

First connect exchanges a six-digit code for a persistent token. Every later ingest must present that token, and an unrecognised one is rejected with `MacReceiverError.unauthorized`. The code is six digits and numeric; nothing else pairs.

## Delivery is at-least-once

The sender keeps a payload queued until the send returns without throwing, and retries with exponential backoff — 2s, 4s, 8s, capped at five minutes. State is written to disk on every change, so a phone that loses the network mid-export, or is killed between the send and the acknowledgement, resumes instead of dropping samples.

**The receiver must therefore expect duplicates.** A send that succeeds on the wire but fails afterwards is retried and arrives twice. Deduplicate on `uuid`, which is stable for a given HealthKit sample.

After a configurable number of failures a payload stops being retried automatically. It is **kept, not deleted** — silently losing health data is worse than a queue that needs draining — and is handed back by `drainExhausted()`.

## Anchors

The exporter stores one HealthKit query anchor per metric type. Losing an anchor is wrong in both directions: without one the next launch either re-reads the entire history or, if it starts from "now", silently skips everything recorded while the app was closed. Clearing an anchor deliberately is the supported way to force a backfill.
