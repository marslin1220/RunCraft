# Ubiquitous Language

A glossary of the RunCraft domain. When the same word means different things in
different layers (our model, Apple's WorkoutKit, user-facing UI), this file
picks the canonical name and tells you which aliases to stop using.

## Training Science (Jack Daniels)

| Term            | Definition                                                                              | Aliases to avoid                |
| --------------- | --------------------------------------------------------------------------------------- | ------------------------------- |
| **VDOT**        | A scalar (30–85) representing a runner's effective VO₂max, derived from a race result   | "fitness level", "running power" |
| **Pace Zone**   | One of the five Jack Daniels training intensities derived from VDOT: E, M, T, I, R       | "training zone", "intensity tier"|
| **E (Easy)**    | 54–63% of VO2max — long aerobic base work and recovery between hard days                 | "recovery pace"                  |
| **M (Marathon)**| 73% of VO2max — sustainable race effort for marathon distance                            | "M pace"                         |
| **T (Threshold)**| 82% of VO2max — comfortably hard tempo work; lactate-clearance training                 | "tempo pace" (UI is fine, code uses Threshold) |
| **I (Interval)**| 91% of VO2max — 3–5 min reps that hit and sustain VO2max                                  | "VO2max pace"                    |
| **R (Repetition)**| ~mile race pace — short fast reps with long recoveries; targets economy and speed       | "rep pace", "speed work"         |
| **Pace Range**  | A two-sided pace target (min/max sec per km) attached to a workout step                  | "speed alert" (Apple's name)     |
| **HR Zone**     | One of five heart rate training bands (1 = very light → 5 = maximum) displayed during Active Workout | "heart rate zone", "zone" (unqualified) |
| **PaceZoneName**| Enum of the five Daniels zones (E/M/T/I/R). Lives in **VDOTEngine** as of `63839b7`.    | _previously in RunCraftModels_   |

## Race Plan Lifecycle

| Term                | Definition                                                                                         | Aliases to avoid              |
| ------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------- |
| **Race Goal**       | The user-chosen race (name, date, distance) that anchors a periodised plan                          | "target race", "event"        |
| **Training Plan**   | The 16-week periodised schedule generated for a Race Goal                                           | "schedule", "program"         |
| **Training Phase**  | One of *Base*, *Build*, *Peak*, *Taper* — a 4-week block of the Training Plan                       | "training period"             |
| **Training Week**   | One of 16 weeks inside a Training Plan; belongs to a Training Phase                                 | "week", "block of training"   |
| **Planned Session** | One day of training inside a Training Week (Session Type + target distance/time)                    | "scheduled run", "workout"    |
| **Session Type**    | The character of a Planned Session: *Easy*, *Tempo*, *Interval*, *Long*, *Repetition*, *Rest*       | "workout type"                |
| **Completed Workout**| A recorded run linked back to a Planned Session via `plannedSessionId`                              | "log entry", "history item"   |

## Workout Composition (Workshop)

| Term                | Definition                                                                                         | Aliases to avoid                |
| ------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------- |
| **Workout Template**| A reusable, ordered list of Workout Blocks with a name — the unit the user can Save and Start       | "workout", "session", "routine" |
| **Workout Block**   | One element in a Workout Template — either a Step or a Repeat Group                                | "section"                       |
| **Workout Step**    | A single segment with a Step Kind, a Step Goal, and an optional Step Alert                          | "interval" (Apple's term)       |
| **Repeat Group**    | A Workout Block holding 2+ Steps repeated N times (e.g. 5× of 400 m work + 90 s recovery)           | "set", "round", "block"         |
| **Step Kind**       | The role of a Step: *Warm-up*, *Work*, *Recovery*, *Cool-down*                                      | "phase", "type"                 |
| **Step Goal**       | What ends a Step: *Distance* (metres), *Time* (seconds), or *Open-ended* (lap-button)               | "target"                        |
| **Step Alert**      | The intensity guidance Apple Watch enforces during a Step: *Pace Range* or *Heart Rate Range*       | "zone"                          |
| **Source**          | Where a Workout Template came from when opened in detail: *Yours*, *Template*, *Plan Session*       | "origin"                        |
| **Preset**          | A Workout Template hard-coded in `WorkoutPresets.all` (Yasso 800s, Tempo Run, etc.)                 | "default", "built-in"           |
| **Duplicate**       | Make a user-owned copy of a Preset or Plan-derived Workout Template, written to *Yours*             | "clone", "fork"                 |

## Active Workout (Apple Watch)

The in-progress state after the user starts a workout on Apple Watch. Managed by
`WorkoutSessionManager`; surfaced in `ActiveWorkoutView` and the **Live Activity**.

| Term                  | Definition                                                                                          | Aliases to avoid                     |
| --------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------ |
| **Active Workout**    | A workout currently being tracked on Apple Watch (phase = running or paused)                        | "live workout", "current session"    |
| **Workout Phase**     | The lifecycle state of an Active Workout: *inactive*, *running*, *paused*, *ended*, *failed*        | "status", "state"                    |
| **Step Name**         | Human-readable label for the current Workout Step shown on Watch during Active Workout (e.g. "Rep 2/5 · Run") | "interval name", "step label" |
| **Step Progress**     | A 0–1 scalar representing how far through the current Step's goal the runner is                      | "completion", "progress fraction"    |
| **Elapsed Time**      | Total seconds the Active Workout has been running (paused time excluded)                             | "duration", "time"                   |
| **Pace Deviation**    | Whether the runner's current pace is *ahead*, *behind*, or *on target* relative to the Step's Pace Range | "pace status", "pace comparison" |
| **Watch Schedule**    | The synced payload of this week's Planned Sessions and Training Paces delivered to Apple Watch via WCSession | "watch data", "sync payload"   |
| **Schedule Cache**    | A local `UserDefaults` copy of the Watch Schedule on the Watch, restored instantly on relaunch      | "offline data", "cached schedule"    |
| **Live Activity**     | The iOS Lock Screen and Dynamic Island display showing real-time Active Workout metrics on iPhone    | "lock screen widget", "notification" |

## App Surfaces (User-facing)

| Term             | Definition                                                                                                | Aliases to avoid          |
| ---------------- | --------------------------------------------------------------------------------------------------------- | ------------------------- |
| **Plan tab**     | The dashboard: race countdown, today's Pace Zones, current Training Week's Planned Sessions               | "calendar tab"            |
| **Workshop tab** | The workout authoring surface; root is a list with three Segments                                          | "editor tab"              |
| **Yours**        | Workshop segment listing user-saved Workout Templates                                                      | "custom", "my workouts"   |
| **Templates**    | Workshop segment listing built-in Presets                                                                  | "library", "presets tab"  |
| **Plan**         | Workshop segment listing this week's Planned Sessions, converted on the fly to Workout Templates           | (collides with "Plan tab" — disambiguate by context) |
| **Workout Detail**| Read-only preview of a Workout Template with the Start button                                              | "summary page"            |
| **Workout Editor**| The drag-and-drop authoring surface (Steps, Repeat Groups, Edit sheets)                                    | "compose view"            |
| **Sessions Wheel**| The Apple Watch home view page showing this week's Planned Sessions as a vertically-scrollable wheel; today's session is centred by default | "training list", "schedule list" |
| **Paces Wheel**  | The Apple Watch home view page (swipe left from Sessions Wheel) showing Training Paces as a wheel          | "pace list"               |
| **Start**        | Send the Workout Template to the paired Apple Watch and auto-launch the Watch app via HealthKit Workout Mirroring | "begin", "run" |

## Architectural Seams

These are the deep modules that own a domain responsibility behind a small
interface. New code should reach for the seam, never around it.

| Seam                          | Module          | Responsibility                                                                  |
| ----------------------------- | --------------- | ------------------------------------------------------------------------------- |
| **WorkoutTemplateRepository** | RunCraftModels  | The only path to persist, query, or remove **Workout Templates**. Replaces direct `@Dependency(\.defaultDatabase)` in feature reducers. |
| **AppleWatchSync**            | AppleWatchSync  | All WCSession and HealthKit Watch interaction lives here — `WatchConnectivityClient` (schedule sync), `WorkoutPlanBuilder` (model→`WorkoutPlan`), `HKWatchTriggerClient` (auto-launch). |
| **WorkoutSessionManager**     | RunCraftWatch Watch App | Owns the `HKWorkoutSession` + `HKLiveWorkoutBuilder` lifecycle and the interval state machine that advances through flattened Workout Steps. |
| **TrainingWeek.current**      | RunCraftModels  | Single static function that answers _"which `TrainingWeek` contains this `Date`?"_ Used by both the Plan tab and the Workshop Plan segment. |
| **VDOTCalculator.paceRange**  | VDOTEngine      | Single-zone lookup: `paceRange(for: PaceZoneName, vdot: Double) → PaceRange`. The deep way to ask "what's T pace for VDOT 40?" |

## Apple Framework Bridges

When mapping between RunCraft types and Apple framework types, always
disambiguate by qualifying with the framework name. **Never** drop the qualifier
in code or docs when both meanings are in scope. All Apple-side conversions
live in the **AppleWatchSync** module.

| RunCraft term     | Apple equivalent              | Notes                                                            |
| ----------------- | ------------------------------ | ---------------------------------------------------------------- |
| Workout Template  | `WorkoutKit.WorkoutPlan`       | Built via `WorkoutPlanBuilder.makePlan(from:)` in AppleWatchSync |
| Workout Block (step) | `WorkoutKit.IntervalBlock`  | Single Step becomes a one-iteration IntervalBlock                |
| Repeat Group      | `WorkoutKit.IntervalBlock`     | N-iteration block with nested IntervalSteps                      |
| Workout Step      | `WorkoutKit.IntervalStep`      | Apple tags purpose as `.work` or `.recovery`                     |
| Workout Step (warmup) | `WorkoutKit.WorkoutStep` (warmup slot) | First Step of kind `.warmup` is hoisted into CustomWorkout's warmup slot |
| Workout Step (cooldown) | `WorkoutKit.WorkoutStep` (cooldown slot) | Last Step of kind `.cooldown` is hoisted into CustomWorkout's cooldown slot |
| Pace Range alert  | `WorkoutKit.SpeedRangeAlert`   | sec/km → m/s reciprocal: max speed = min pace                    |
| Heart Rate alert  | `WorkoutKit.HeartRateRangeAlert` | BPM range, `WorkoutAlertMetric.countPerMinute`                 |
| Active Workout    | `HKWorkoutSession` + `HKLiveWorkoutBuilder` | Session provides lifecycle; Builder collects and saves metrics |
| Live Activity     | `ActivityKit.Activity<WorkoutActivityAttributes>` | Started/updated/ended by `WorkoutSessionManager` |

## Relationships

- A **Race Goal** has exactly one **Training Plan**.
- A **Training Plan** owns 16 **Training Weeks**; each belongs to a **Training Phase**.
- A **Training Week** owns 7 **Planned Sessions** (one per `dayOfWeek`, including Rest days).
- A **Planned Session** has a **Session Type**; a **Completed Workout** points back to its **Planned Session**.
- A **Workout Template** owns an ordered list of **Workout Blocks**.
- A **Workout Block** is either one **Workout Step** *or* one **Repeat Group**.
- A **Repeat Group** owns 1+ **Workout Steps** (no nested groups).
- A **Workout Step** has one **Step Kind**, one **Step Goal**, and zero-or-one **Step Alert**.
- A **Planned Session** is converted to a **Workout Template** at view time by `PlanSessionAdapter`; the user can Duplicate it to make it permanent.
- An **Active Workout** runs exactly one flattened sequence of **Workout Steps** derived from the **Workout Template**'s **Workout Blocks** (Repeat Groups are unrolled).
- A **Live Activity** mirrors the **Active Workout**'s state to the iPhone Lock Screen while the Watch workout runs.
- The **Watch Schedule** is synced via WCSession and locally persisted as a **Schedule Cache** on the Watch.

## Example dialogue

> **Dev:** "The user taps Start on a Workout Template. What happens end-to-end?"

> **Coach:** "iPhone sends the **Watch Schedule** and the **Workout Template** blocks to Watch via WCSession, then calls `HKHealthStore.startWatchApp(toHandle:)`. Watch auto-launches, `WorkoutSessionManager` receives the blocks, flattens **Repeat Groups** into individual **Workout Steps**, and begins an `HKWorkoutSession`. The first **Step Name** and **Step Progress** appear in `ActiveWorkoutView` immediately."

> **Dev:** "What if the runner is going faster than the **Pace Range**?"

> **Coach:** "`WorkoutSessionManager` sets **Pace Deviation** to `.ahead`. `ActiveWorkoutView` colours the pace cyan; the **Live Activity** on the iPhone Lock Screen does the same via `WorkoutActivityAttributes.ContentState`."

> **Dev:** "When a distance step completes, how does the machine know?"

> **Coach:** "`HKLiveWorkoutBuilderDelegate.didCollectDataOf` fires. The manager checks `totalMetres − stepStartMetres ≥ step goal`. When true it increments `currentStepIndex`, resets **Step Progress** to 0, and updates **Step Name** to the next entry."

> **Dev:** "And the **Completed Workout** — when does that land in HealthKit?"

> **Coach:** "When the user taps End, `session.end()` triggers `workoutSession(_:didChangeTo:.ended)`. The manager calls `builder.finishWorkout()`, which writes the `HKWorkout` to HealthKit. The existing `HealthKitClient.recentWorkouts()` query on iPhone picks it up and creates the **Completed Workout** record."

## Flagged ambiguities

### "Workout"
The bare word "workout" was used in early discussion for three different things:
**Workout Template** (a reusable design), **Planned Session** (a day on the calendar),
and **Completed Workout** (a logged run). Always qualify which one you mean.
**Recommendation:** never use bare "workout" in code or PRs.

### "Plan"
Three concurrent meanings:
1. **Training Plan** — the 16-week periodised schedule.
2. **Plan tab** — the dashboard surface.
3. **Plan** Workshop segment — this week's Planned Sessions inside the Workshop tab.
Plus Apple's `WorkoutKit.WorkoutPlan` is a fourth meaning at the framework
boundary. **Recommendation:** the un-qualified noun "Plan" is reserved for
**Training Plan**; everywhere else use the longer name ("Plan tab",
"Plan segment", "WorkoutKit.WorkoutPlan").

### "Step" / "Block" (RunCraft vs WorkoutKit)
Both frameworks use `Step` and `Block`/`IntervalBlock` for related but distinct
things. A RunCraft **Workout Step** is always inside a **Workout Block**; a
WorkoutKit `WorkoutStep` is only the warmup/cooldown slot, and inner steps
are `IntervalStep`s inside `IntervalBlock`s. **Recommendation:** never drop
the module qualifier when both are in scope.

### "Start" (resolved — behavior changed)
Previously "Start" sent to Watch and the user had to tap *Start* in the native
Workout app. As of the HealthKit Workout Mirroring implementation, **Start**
now auto-launches the RunCraft Watch app and begins the **Active Workout**
without any Watch interaction. The old guidance ("prefer 'Send to Apple Watch'")
is retired. **Start** in UI copy is now accurate and unambiguous.

### "Template"
Means two different things in the UI: the **Templates** segment (built-in
**Presets** only) and the underlying data type **Workout Template** (the
storage type for any saved or generated workout, presets included).
**Recommendation:** in code use **WorkoutTemplate**; in UI/PR copy say
"preset" when you mean the built-in fixtures and "template" only when you
mean the **Templates** segment specifically.

### "Zone"
Used unqualified to mean two distinct things: **HR Zone** (1–5 heart rate
band during **Active Workout**) and the Jack Daniels **Pace Zone** (E/M/T/I/R).
**Recommendation:** always qualify — "HR Zone 4" vs "Pace Zone T".

## Resolved ambiguities (now fixed in code)

- **Library button vs Templates segment.** The legacy `TemplateLibrarySheet`
  exposed presets and saved templates as a sheet inside the editor;
  the P3 Workshop restructure made the segmented list the only path.
  The sheet, its state and three orphan actions were removed in commit
  `27de8b0` (architecture review candidate #3).
- **Persistence inside the editor.** WorkoutEditor used to call
  `@Dependency(\.defaultDatabase)` directly. After commit `f43bbda`
  (candidate #1) every save/load/all/delete goes through
  **WorkoutTemplateRepository**.
- **Bespoke "current week" derivation.** PlanView and the Workshop
  Plan segment used to compute current week independently; the
  Workshop segment additionally loaded all 112 sessions and filtered
  client-side. Both now call `TrainingWeek.current(in:at:)` and the
  Workshop segment narrows its query to `where(weekId == currentWeekId)`
  (commit `99de872`, candidate #5).
- **WorkoutKit inside WorkshopFeature.** WorkoutKitClient and
  WorkoutPlanBuilder used to ride along with anything linking
  WorkshopFeature. They now live in the dedicated **AppleWatchSync**
  module (commit `9c44e05`, candidate #6) so a future `WatchAppFeature`
  can sync from the wrist without pulling in the editor or the shell.
- **"Start" meaning Send-only.** Previously Start sent the Workout Template
  to Watch via WorkoutScheduler and the user had to tap in the native
  Workout app. HealthKit Workout Mirroring now auto-starts the Watch app.
  "Start" in UI copy accurately describes the full action end-to-end.
