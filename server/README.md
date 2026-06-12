# SwimCoach server — sync contract (STUB, not implemented)

This directory defines the **future** cloud "brain" for SwimCoach. **No
implementation lives here yet** — only the contract, so the watch's networking
module (`apps/garmin/source/SyncClient.mc`) can be written against a stable shape
and wired up later without touching the rest of the app.

Planned hosting: **AWS serverless** (API Gateway → Lambda → DynamoDB). Nothing
about the contract below depends on that choice; it is just JSON over HTTPS.

The watch keeps **all** networking behind the single `SyncClient` module. Today
that module is a no-op stub with this contract baked in as the target. Wiring it
up later means filling in two calls, not refactoring the app.

---

## Authentication (planned)

Per-user bearer token provisioned during pairing, sent as
`Authorization: Bearer <token>`. The watch stores it in app properties. The
contract below omits auth headers for brevity.

## 1. Pre-session GET — fetch the day's plan

```
GET /v1/plan/today
```

**Response 200** — the personalised plan for today. Every field is advisory; the
watch must run correctly with an empty or absent plan (offline-first).

```json
{
  "version": 1,
  "planId": "2026-06-12-base",
  "date": "2026-06-12",
  "mode": "swim",
  "poolLengthMeters": 25.0,
  "targetDistanceMeters": 1500,
  "breathing": {
    "protocol": "box",
    "hrTargetOffsetBpm": 25
  },
  "notes": "Aerobic base. Easy kick on the last 300."
}
```

Failure / offline → the watch ignores it and uses local settings + `defaults.json`.

## 2. End-of-session POST — upload the completed session

```
POST /v1/sessions
Content-Type: application/json
```

The watch builds this payload from `LapEngine` + `HrMonitor` and POSTs once at the
end of a session. It is the **summary**, not a live stream.

```json
{
  "version": 1,
  "clientSessionId": "uuid-generated-on-watch",
  "planId": "2026-06-12-base",
  "startedAt": "2026-06-12T06:01:13Z",
  "endedAt": "2026-06-12T06:43:55Z",
  "mode": "swim",
  "poolLengthMeters": 25.0,
  "totalDistanceMeters": 1500.0,
  "lapCount": 60,
  "movingTimeSec": 2310,
  "totalTimeSec": 2562,
  "splits": [
    { "index": 1, "distanceMeters": 25.0, "durationSec": 38, "restAfterSec": 0 },
    { "index": 2, "distanceMeters": 25.0, "durationSec": 39, "restAfterSec": 12 }
  ],
  "breathingSets": [
    {
      "startedAt": "2026-06-12T06:20:01Z",
      "protocol": "box",
      "baselineHrBpm": 148,
      "targetHrBpm": 123,
      "endReason": "hrTargetMet",
      "durationSec": 47
    }
  ],
  "hrRecovery": {
    "windowSec": 60,
    "startBpm": 150,
    "endBpm": 118,
    "dropBpm": 32
  }
}
```

- `mode`: `"swim" | "kick"`.
- `endReason`: `"hrTargetMet" | "hardCap" | "cancelled"`.
- `hrRecovery` omitted when HR was unavailable.

**Response 201**

```json
{ "serverSessionId": "...", "accepted": true }
```

### Idempotency

`clientSessionId` is a UUID minted on the watch. Re-POSTing the same id must be a
no-op server-side (the watch may retry after a dropped connection). The server
returns the same `serverSessionId` for a given `clientSessionId`.

---

## Contract invariants (so platforms agree)

- All timestamps are **ISO-8601 UTC**.
- All distances are **metres**, durations **seconds**, HR **bpm** — matching
  `packages/behavior-spec/defaults.json`.
- `totalDistanceMeters` MUST equal `lapCount × poolLengthMeters` (manual-lap
  invariant from the design rationale — the server may reject payloads that
  violate it).
- The payload is **derived from the behavior-spec**, so adding a platform means
  reusing this shape, not redefining it.

## Not in scope yet

No auth implementation, no storage schema, no Lambda/IaC. Add those here when the
backend work actually begins; until then the watch treats sync as best-effort and
never blocks the workout on it.
