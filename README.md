# SwimCoach

A personalised swim-training app built around **manual-lap accuracy** and
**HR-targeted breathing recovery**. The first platform is a **Garmin Connect IQ**
app for the **Instinct 2X Solar**; the repo is laid out so Apple Watch, Wear OS
and a cloud backend can be added later **without rewriting the core behaviour**.

The central idea: the *behaviour* (state machine, breathing timings, HR
thresholds, default pool length) lives once, as language-neutral data, in
[`packages/behavior-spec`](packages/behavior-spec). Every platform is a thin
implementation that reads that spec. Reason about the behaviour once; ship it
everywhere.

## What it does

- **Manual laps are the accuracy core.** Distance is always
  `confirmed laps × measured pool length`. You press a button at each wall. Never
  derived from stroke detection, never from GPS.
- **Swim and Kick modes** share one lap engine. Kick records under a generic
  sub-sport so the watch doesn't fabricate stroke/SWOLF numbers.
- **Rest → breathing set.** At the wall, start a vibration-guided breathing set
  (box 4-4-4-4 by default) with a big live heart-rate readout. It **auto-stops**
  when your smoothed HR has come down to target — robustly: debounced, null-safe,
  and hard-capped so you're never trapped. Then **"Resuming 3·2·1"** and back to
  rest.
- **End-of-session recovery** reuses the same breathing engine and records your
  HR recovery (drop over 60 s).

## The hard constraints (why it's built this way)

These are deliberate and grounded in how the hardware behaves underwater. Full
detail in [`docs/design-rationale.md`](docs/design-rationale.md):

1. **GPS can't measure pool distance** (submerged wrist, error dwarfs the pool) —
   manual laps only; GPS reserved for a future open-water mode.
2. **Kick drills break arm-based stroke detection** — no stroke/SWOLF in kick.
3. **Wrist HR during swimming is gated** — HR may be unavailable; handled
   gracefully with a setup hint, never faked.
4. **Memory is tiny (~256–300 KB)** — no big bitmaps, no per-frame allocation.
5. **Monochrome, button-only** — high-contrast, glanceable; haptics lead, visuals
   back up.

## Repository layout

```
.
├── apps/
│   ├── garmin/          # Connect IQ app (Monkey C) — built, the v1 platform
│   ├── watchos/         # placeholder: how watchOS implements the spec
│   └── wearos/          # placeholder: how Wear OS implements the spec
├── packages/
│   └── behavior-spec/   # source of truth: breathing protocols, state machine, defaults (JSON)
├── server/              # FUTURE AWS "brain" — sync contract defined, no impl yet
├── docs/
│   └── design-rationale.md
└── README.md
```

## Build the Garmin app

You need the Connect IQ SDK and a developer key. Quickstart:

```sh
cd apps/garmin
monkeyc -f monkey.jungle -d instinct2x -o bin/SwimCoach.prg -y developer_key
connectiq && monkeydo bin/SwimCoach.prg instinct2x
```

Run the unit tests (lap maths + HR auto-stop):

```sh
cd apps/garmin
monkeyc -f monkey.jungle -d instinct2x --unit-test -o bin/SwimCoachTest.prg -y developer_key
monkeydo bin/SwimCoachTest.prg instinct2x -t
```

Full instructions, code map and the `// VERIFY` checklist are in
[`apps/garmin/README.md`](apps/garmin/README.md).

## How the pieces fit

- **`packages/behavior-spec`** — the single source of behaviour. Edit timings or
  transitions here; platforms pick them up.
- **`apps/garmin`** — reads the spec (embedded as JSON resources) and implements
  it for Connect IQ. Lap engine, HR auto-stop and breathing controller are
  independently testable.
- **`server`** — the future sync contract (end-of-session POST + day-plan GET).
  The watch keeps all networking behind one `SyncClient` module, so wiring the
  backend is a two-method change.
- **`apps/watchos` / `apps/wearos`** — documented mappings of the same spec to
  the next platforms.
