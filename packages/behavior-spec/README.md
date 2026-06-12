# behavior-spec — the source of truth

This package holds **language-neutral** behaviour for SwimCoach as plain JSON.
It contains no platform code. Every platform (Garmin today; Apple Watch and
Wear OS later) reads these files and implements a *thin* layer that obeys them,
so the core training behaviour is identical everywhere and only has to be
reasoned about once.

> **Golden rule:** if a behaviour can be expressed as data, it lives here — not
> hardcoded in a platform. Timings, thresholds, debounce windows, caps, default
> pool length and state transitions are all data.

## Files

| File | What it defines |
|------|-----------------|
| `state-machine.json` | The session states (`MODE_SELECT → ACTIVE → REST → BREATHING → REST → … → SUMMARY`), the abstract events that drive transitions, and the side-effects each transition fires. End-of-session `RECOVERY` is reachable from `REST`. |
| `breathing-protocols.json` | Per-protocol phase timings (box 4-4-4-4, 4-7-8, coherent 5-5) and the symbolic haptic cue for each phase (`inhale`=long, `exhale`=two short, `hold`=tap, `done`=boom). |
| `defaults.json` | Tunable defaults & engineering constants: default pool length, HR target offset/floor, smoothing window, **auto-stop debounce / hard cap / null-handling**, recovery duration, UI countdown, lap debounce. |

## How a platform consumes this

1. **Load** the JSON (Garmin: embedded as `Rez.JsonData` resources; iOS/Wear: bundle
   the files or fetch them).
2. **Drive the state machine** from `state-machine.json` rather than hardcoding
   transitions. `event` names are abstract and mapped to physical buttons per
   device. `effects` / `onEnter` names are evaluated by the platform's
   controller (see the Garmin `SessionController`).
3. **Read timings & thresholds** from `defaults.json` and
   `breathing-protocols.json` at runtime; never bake the numbers into code.
4. **Map symbolic haptics** to the device vibration API. The *felt pattern* is
   the contract; the platform translates `kind`/`pulses`/`dutyCycle`/`lengthMs`.

### Garmin specifics
Connect IQ embeds these JSONs as `jsonData` resources. Because the SDK build only
packages files under a resource path, the Garmin app **vendors a synced copy**
under `apps/garmin/resources/spec/`. The copy is byte-identical to the canonical
files here — keep them in sync:

```sh
cp packages/behavior-spec/*.json apps/garmin/resources/spec/
```

(That copy step is the only duplication; the canonical definition is always this
package.)

## Versioning

Each file carries a top-level integer `version`. Bump it on any
behaviour-changing edit so platforms can detect a spec they don't understand and
fail safe (fall back to embedded defaults) rather than misbehave.

## Units (always explicit)

- Durations: **milliseconds** (`...Ms`) unless the key says `Sec`.
- Distance: **metres** (decimal allowed).
- Heart rate: **bpm**.
