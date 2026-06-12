# SwimCoach — Design Rationale

This document captures the **why** behind SwimCoach's non-obvious decisions.
Several of them look like missing features until you understand how the hardware
actually behaves underwater. **Do not "improve" these away** — they are
deliberate and grounded in the physics of the sensors and the constraints of the
watch. Code that touches these areas should reference this file.

The first hardware target is the **Garmin Instinct 2X Solar**: a monochrome MIP
display, five physical buttons (no touch), and a very small Connect IQ memory
budget (~256–300 KB for the whole app).

---

## 1. Manual laps are the accuracy core — distance is never inferred

**Distance is always `confirmed laps × measured pool length`.** The user presses a
button at each wall. We never derive pool distance from auto-detected stroke
counts and never from GPS.

Why: stroke auto-detection is an estimate that drifts, and it is wrong for drills
(see §3). A wall touch is a ground-truth event. One button press = one known
length = exact distance. Pool length is configurable in decimal metres (e.g.
18.5) because real pools are not all 25 m.

Consequence in code: `LapEngine` is the single source of distance. Nothing else is
allowed to compute distance. Pace and splits are derived from confirmed laps and
their timestamps only.

## 2. GPS cannot measure pool distance

The wrist is submerged on every stroke, so GPS loses lock repeatedly, and even
with lock the position error (several metres) dwarfs a 25 m pool. Averaged over a
session this produces nonsense.

Therefore GPS is **disabled for pool and kick**. It is acceptable **only** for a
future open-water mode, where distances are large and the error is tolerable
(`defaults.json → openWater.allowGps`). Pool/kick distance must always come from
manual laps.

## 3. Kick drills break arm-based stroke detection

During a kick set the arms are extended on a board (or at the streamline) and do
not stroke. The wrist sensor sees no stroke signal, so any stroke/SWOLF/cadence
number the watch produces is fabricated.

Therefore **Kick mode records under a generic sub-sport** so the watch does **not**
attempt stroke detection, and SwimCoach self-computes distance from manual laps.
Kick mode exposes only: distance, splits, pace, rest, total time. **No stroke,
SWOLF, or kick-cadence fields** — we refuse to invent them. Swim and Kick share
the exact same `LapEngine`; only the recording sub-sport and the displayed
metric set differ.

## 4. Wrist HR during swimming is gated, and may be unavailable

On the Instinct 2X, wrist optical HR is **not** streamed during swim activities
unless the user explicitly enables *"Wrist HR during swimming"* in the system
activity settings. A paired **chest strap takes priority** and is more reliable
(optical HR underwater is noisy). The app cannot force either on.

Therefore the HR pipeline must treat **HR-absent as a first-class state**, not an
error:
- `currentHeartRate` can be `null`; null readings never count toward the
  breathing auto-stop (they reset the debounce — see §5).
- When HR is unavailable, the breathing set still runs on its hard-cap timer and
  the UI surfaces a one-line **setup hint** ("Enable Wrist HR during swimming, or
  pair a strap") instead of showing a fake number.

## 5. The HR auto-stop is robust by design, not a naive `if`

A breathing set ends when the swimmer's heart rate has actually come down — but a
single dip below target is meaningless given how jumpy optical HR is. The stop
logic (encoded in `defaults.json → autoStop` and implemented in `HrMonitor`) is:

- **Smoothing** — compare a short rolling average (default 5 samples), and display
  that same smoothed value, not the raw jumpy reading.
- **Debounce** — smoothed HR must stay `≤ target` continuously for ~4 s before we
  stop. Any sample above target resets the timer.
- **Null handling** — dropped/absent readings do **not** count as below target;
  they reset the debounce. A stale sensor cannot fake a stop.
- **Hard cap** — end after ~120 s no matter what, so a plateau above target never
  traps the user. That exit shows a **"target not reached"** state.
- **Relative target** — default target = end-of-set HR − 25 bpm (configurable),
  clamped to an absolute floor so we never chase an impossible number.

On a real stop ("boom"), a done-vibration fires and the UI runs **"Resuming
3 · 2 · 1"**, then returns to the **rest** screen. The user stays in rest until
they press the lap button to push off — we never auto-launch the next length.

## 6. End-of-session recovery reuses the breathing controller

The closing recovery phase is the **same** breathing controller with **no HR
target** and a **fixed duration**. It additionally captures **HR recovery** (drop
over 60 s) as a summary stat. Reuse, not a parallel implementation, keeps the
behaviour and the haptics identical.

## 7. Memory is tiny (~256–300 KB)

The Instinct 2X gives a Connect IQ app a very small heap. So:
- **No large bitmaps.** The launcher icon is a tiny monochrome PNG; everything
  else is drawn with primitives in `onUpdate`.
- **No per-frame allocation.** Views reuse member objects and pre-sized buffers;
  the HR rolling buffer is a fixed-length ring, not a growing list.
- **One networking module** (`SyncClient`) so the (future) sync code is isolated
  and the rest of the app stays lean.
- Lean strings, no unused resources, single shared `LapEngine`/`BreathingController`.

## 8. Monochrome, button-only UI

The MIP display is monochrome and there is **no touchscreen**. So the UI is
**high-contrast and glanceable**: big numerals (the live HR fills the breathing
screen), a single expanding/contracting **ring** as the breathing cue, and at
most a small phase word — trivially strippable to **HR-only**. The **haptics are
the primary guide; the visual is backup** (you can't watch the screen with your
face in the water). All interaction is via the five physical buttons through an
abstract event layer (`SELECT` / `BACK` / `LAP` / …), mapped per device.

---

## Pointers into the code (Garmin)

| Constraint | Where it lives |
|------------|----------------|
| §1, §2 manual-lap-only distance | `source/LapEngine.mc` |
| §3 kick sub-sport, metric set | `source/SessionController.mc`, `source/views/ActiveView.mc` |
| §4 HR availability handling | `source/HrMonitor.mc` |
| §5 auto-stop debounce/cap/null | `source/HrMonitor.mc` (+ tests) |
| §6 recovery reuse | `source/BreathingController.mc`, `source/SessionController.mc` |
| §7 memory discipline | all views; `source/SyncClient.mc` |
| §8 monochrome button-only UI | `source/views/*`, `source/delegates/*` |
| all tunables | `packages/behavior-spec/*.json` |
