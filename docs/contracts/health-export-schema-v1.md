# Health Export Schema v1

LAN-only JSON contract between `Apps/machHealth` (iOS exporter) and Mac consumers
(machSound first). Source of truth for types: `Packages/HealthExportKit`.

## Envelope

```json
{
  "schema": 1,
  "device": "lars-iphone",
  "sentAt": "2026-06-10T21:14:03+02:00",
  "samples": []
}
```

- `schema` — major version; receivers reject unknown majors.
- `device` — stable exporter identifier chosen by the user.
- `sentAt` — ISO-8601 post time on the phone.
- `samples` — at-least-once delivery; dedupe on `uuid`.

## Sample

```json
{
  "uuid": "HK-…",
  "type": "heartRate",
  "value": "61",
  "unit": "bpm",
  "start": "2026-06-10T21:13:00+02:00",
  "end": "2026-06-10T21:13:00+02:00",
  "source": "Apple Watch",
  "meta": {}
}
```

## Metric types (v1)

| type | unit | notes |
|---|---|---|
| `heartRate` | `bpm` | |
| `hrvSDNN` | `ms` | |
| `restingHeartRate` | `bpm` | |
| `sleepStage` | `stage` | value: `awake`, `rem`, `core`, `deep` |
| `steps` | `count` | |
| `activeEnergy` | `kcal` | |
| `workout` | `type` | value: HK workout activity type name |
| `mindfulMinutes` | `min` | |

## Transport

- Bonjour service: `_machhealth._tcp`
- POST `application/json` to paired Mac receiver
- HMAC token from 6-digit first-connect pairing (v1 floor)
- No cloud, no third-party brokers

## Consumer rules

- Derive features on the Mac (arousal, sleep quality); do not persist raw streams by default.
- Assume minute-scale latency unless H0 measurements prove better.
