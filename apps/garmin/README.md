# SwimCoach — Garmin (Connect IQ)

The first SwimCoach platform: a Connect IQ watch-app written in Monkey C,
targeting the **Garmin Instinct 2X Solar** (monochrome MIP, five buttons, no
touch, ~256–300 KB app memory). It is a *thin* implementation of the shared
behaviour in [`packages/behavior-spec`](../../packages/behavior-spec) — the
state machine, breathing timings and thresholds are loaded from that spec as
JSON resources, not hardcoded.

> Read [`docs/design-rationale.md`](../../docs/design-rationale.md) first. Several
> things that look missing (no stroke counts, no GPS, HR sometimes "--") are
> deliberate and explained there.

## What it does (v1 loop)

```
MODE_SELECT ─ START ─▶ ACTIVE(swim|kick) ─ LAP ─▶ (laps × poolLength = distance)
     ▲                      │ BACK
     │ DONE                 ▼
  SUMMARY ◀─ STOP ─────── REST ── DOWN ─▶ BREATHING ──(HR target / cap)──▶ REST
     ▲                      │ UP                              "Resuming 3·2·1"
     └──────── endSession ─ RECOVERY ◀───┘
```

- **Manual laps**: one button press per wall = one confirmed length. Distance is
  always `confirmed laps × pool length`. Never strokes, never GPS.
- **Swim & Kick** share the lap engine; kick records under a generic sub-sport so
  the watch doesn't fabricate stroke metrics.
- **HR-targeted breathing** on rest: big live HR + an expanding/contracting ring,
  vibration-guided box breathing, auto-stops when smoothed HR holds below target
  (debounced, null-safe, hard-capped), then **"Resuming 3·2·1"** back to rest.
- **End-of-session recovery** reuses the breathing controller (no HR target,
  fixed duration) and captures HR recovery (drop over 60 s).

## Code map

| File | Responsibility |
|------|----------------|
| `source/SwimCoachApp.mc` | App entry point (tiny). |
| `source/SessionController.mc` | Drives the state machine **from the spec**; owns the timer, recording session, engines, sync. |
| `source/LapEngine.mc` | Manual-lap distance / splits / pace. Pure & unit-tested. |
| `source/HrMonitor.mc` | HR smoothing + robust auto-stop (debounce / null / cap). Pure & unit-tested. |
| `source/BreathingController.mc` | Runs protocol phases + haptics; HR-target and fixed-duration modes. |
| `source/Haptics.mc` | Maps spec haptic cues → `Attention.vibrate`, guarded by `vibrateOn`. |
| `source/SyncClient.mc` | The single networking module (stub; see `server/README.md`). |
| `source/Spec.mc` | Loads the behavior-spec JSON resources with safe fallbacks. |
| `source/views/*` | Monochrome, glanceable, no per-frame allocation. |
| `source/delegates/InputRouter.mc` | Device-independent button → intent mapping. |
| `source/tests/*` | Unit tests for the lap maths and HR auto-stop. |

## Build & run

Requires the **Connect IQ SDK** (the SDK Manager installs `monkeyc`/`monkeydo`
and device bundles) and a **developer key**.

```sh
# 1) One-time: generate a developer key (if you don't have one)
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem \
        -out developer_key -nocrypt

# 2) Build for the Instinct 2X
monkeyc -f monkey.jungle -d instinct2x -o bin/SwimCoach.prg -y developer_key

# 3) Run in the simulator
connectiq                       # launches the CIQ simulator
monkeydo bin/SwimCoach.prg instinct2x
```

In the simulator, set a heart rate (Simulation ▸ Sensors ▸ Heart Rate) and a
moving HR to exercise the breathing auto-stop. Use the simulated buttons:
**START** = lap/confirm, **BACK** = rest/cancel, **UP/DOWN** = recover/breathe,
long-press = stop.

## Tests

```sh
monkeyc -f monkey.jungle -d instinct2x --unit-test -o bin/SwimCoachTest.prg -y developer_key
monkeydo bin/SwimCoachTest.prg instinct2x -t
```

Covers the lap-engine maths (distance, fractional pool, debounce, pace,
rest-exclusion) and the HR auto-stop logic (smoothing, debounce, null handling,
spike reset, hard cap, no-target recovery).

## Settings (Connect IQ app settings)

| Setting | Default | Notes |
|---------|---------|-------|
| Pool length (m) | 25.0 | Decimal metres allowed. |
| HR target offset (bpm) | 25 | Breathing target = end-of-set HR − offset. |
| Breathing protocol | Box 4-4-4-4 | also 4-7-8, Coherent 5-5. |
| Recovery duration (s) | 60 | End-of-session recovery length. |

Defaults mirror `packages/behavior-spec/defaults.json`.

## Points to VERIFY against your installed SDK

Marked `// VERIFY` in code. Confirm before shipping to hardware:

- `manifest.xml` product id `instinct2x` and `minApiLevel` (JSON resources +
  pool-length config need ≥ 3.x).
- Kick mode's exact `Activity.SUB_SPORT_GENERIC` constant (goal: no stroke
  detection; we self-compute distance).
- The Instinct 2X physical button → `BehaviorDelegate` routing in
  `source/delegates/InputRouter.mc`.
- `Attention.VibeProfile(dutyCycle, lengthMs)` and the `vibrateOn` device
  setting (confirmed against current docs; re-check on device).

## Spec sync

The JSON under `resources/spec/` is a byte-identical copy of the canonical
`packages/behavior-spec/`. Re-sync after any spec change:

```sh
cp ../../packages/behavior-spec/*.json resources/spec/
```
