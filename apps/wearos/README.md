# SwimCoach — Wear OS — PLACEHOLDER

**No code yet.** This directory marks where the Wear OS implementation will live.
It must be a *thin* implementation of
[`packages/behavior-spec`](../../packages/behavior-spec), sharing identical
behaviour with the Garmin and (future) watchOS apps.

## How Wear OS would implement the spec

| Concern | Garmin (today) | Wear OS (planned) |
|---------|----------------|-------------------|
| Language / UI | Monkey C + custom drawing | Kotlin + Jetpack Compose for Wear OS |
| Spec loading | JSON as `Rez.JsonData` resources | bundle the same JSON in `assets/`; parse with kotlinx.serialization |
| State machine | `SessionController` reads `state-machine.json` | a Kotlin `SessionController` reads the same file |
| Lap engine | `LapEngine.mc` | port the same pure logic to Kotlin; reuse the test cases |
| HR + auto-stop | `HrMonitor.mc` | Health Services `ExerciseClient` HR into the same debounce/null/cap logic |
| Recording | `ActivityRecording.Session` | Health Services `ExerciseConfig` (swimming pool / open water) |
| Haptics | `Attention.vibrate` from spec cues | `Vibrator` / `VibrationEffect` mapping the same symbolic cues |
| Buttons | physical buttons via `BehaviorDelegate` | rotating side button + touch |
| Sync | `SyncClient` (single module) | one networking module against the contract in `server/README.md` |

## Hard constraints still apply

Everything in [`docs/design-rationale.md`](../../docs/design-rationale.md) §1–§7
carries over unchanged (manual-lap-only distance, no GPS for pool, no fabricated
kick metrics, graceful HR-unavailable, robust auto-stop, memory discipline on
constrained Wear hardware). Touch + colour relax only the §8 UI constraints.
