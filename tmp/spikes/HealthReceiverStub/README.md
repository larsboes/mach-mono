# HealthReceiverStub (machHealth H0)

LAN receiver for health data. Logs every POST to `~/machhealth/inbox.jsonl` and
tracks per-metric delivery latency — H0's deliverable is the measured latency
table for `Plans/PLAN-machHealth.md`.

```bash
cd tmp/spikes/HealthReceiverStub
swift run
# → listening on :8787, Bonjour _machhealth._tcp
```

Quick smoke test from the Mac itself:

```bash
curl -s -X POST localhost:8787 -H 'Content-Type: application/json' -d '{
  "schema": 1, "device": "test",
  "samples": [{"type":"heartRate","value":61,"unit":"bpm",
    "start":"2026-06-10T11:00:00+02:00","end":"2026-06-10T11:05:00+02:00"}]
}'
```

## iPhone Shortcuts automation (the H0 bridge)

1. Shortcuts → new **Shortcut**:
   - **Find Health Samples** — type *Heart Rate*, where *Start Date is in the last
     30 minutes*, sort *Newest first*.
   - **Repeat with Each** result → build a Dictionary per sample
     (`type: heartRate`, `value: Magnitude of Repeat Item`, `unit: bpm`,
     `start/end: Start/End Date of Repeat Item`, ISO 8601 format).
   - Wrap in a Dictionary `{schema: 1, device: <name>, samples: <list>}` →
     **Get Contents of URL**: POST `http://<your-mac-name>.local:8787/`,
     Request Body = JSON.
2. Duplicate per metric (HRV, Resting HR, Sleep) — sleep samples deliver value as
   stage text; the stub logs whatever arrives.
3. Shortcuts → **Automation** → *Time of Day*, repeat hourly (or every 15 min via
   multiple automations), **Run Immediately** (no confirmation), attach the shortcut.
4. iPhone and Mac on the same network. First run asks for Health read permission
   per type and "allow connecting to local network" — approve both.

Let it run ≥1 week, then copy the printed latency table into
`Plans/PLAN-machHealth.md` (H0 exit criterion).

**Scope honesty:** no auth, plain HTTP, trusted LAN only. Token pairing + TLS
arrive with HealthExportKit (H1/H2). Don't expose port 8787 beyond your LAN.
