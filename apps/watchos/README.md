# SwimCoach — Apple Watch (watchOS) — PLACEHOLDER

**No code yet.** This directory marks where the watchOS implementation will live.
Like the Garmin app, it must be a *thin* implementation of
[`packages/behavior-spec`](../../packages/behavior-spec) — not a reimplementation
of the behaviour.

## How watchOS would implement the spec

| Concern | Garmin (today) | watchOS (planned) |
|---------|----------------|-------------------|
| Language / UI | Monkey C + custom `dc` drawing | Swift + SwiftUI |
| Spec loading | JSON as `Rez.JsonData` resources | bundle the same JSON files; decode with `Codable` |
| State machine | `SessionController` reads `state-machine.json` | a Swift `SessionController` reads the same file |
| Lap engine | `LapEngine.mc` (laps × poolLength) | port the same pure logic to Swift; reuse the unit tests' cases |
| HR + auto-stop | `HrMonitor.mc` | `HKWorkoutSession` + `HKLiveWorkoutBuilder` HR stream into the same debounce/null/cap logic |
| Recording | `ActivityRecording.Session` (swim / generic sub-sport) | `HKWorkoutConfiguration` (`.swimming`, pool vs open-water) |
| Haptics | `Attention.vibrate` from spec cues | `WKInterfaceDevice.play(_:)` / `CHHapticEngine` mapping the same symbolic cues |
| Buttons | physical buttons via `BehaviorDelegate` | Digital Crown + on-screen controls (touch allowed) |
| Sync | `SyncClient` (single module) | one `SyncService` against the same contract in `server/README.md` |

## Hard constraints still apply

The constraints in [`docs/design-rationale.md`](../../docs/design-rationale.md)
are physics, not Garmin quirks — they carry over: manual-lap-only distance, no
GPS for pool, no fabricated stroke metrics in kick, graceful HR-unavailable
handling, robust (debounced/capped) auto-stop. watchOS has a touchscreen and
colour, so the UI can relax §8 (monochrome/button-only) but **not** §1–§6.
