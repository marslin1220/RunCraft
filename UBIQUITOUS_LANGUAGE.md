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
| **Start**        | Send the Workout Template to the paired Apple Watch via WorkoutKit                                         | "begin", "run" (not literal — does NOT start a timer in-app) |

## Apple Framework Bridges

When mapping between RunCraft types and Apple framework types, always
disambiguate by qualifying with the framework name. **Never** drop the qualifier
in code or docs when both meanings are in scope.

| RunCraft term     | Apple equivalent              | Notes                                                            |
| ----------------- | ------------------------------ | ---------------------------------------------------------------- |
| Workout Template  | `WorkoutKit.WorkoutPlan`       | Built via `WorkoutPlanBuilder.makePlan(from:)`                   |
| Workout Block (step) | `WorkoutKit.IntervalBlock`  | Single Step becomes a one-iteration IntervalBlock                |
| Repeat Group      | `WorkoutKit.IntervalBlock`     | N-iteration block with nested IntervalSteps                      |
| Workout Step      | `WorkoutKit.IntervalStep`      | Apple tags purpose as `.work` or `.recovery`                     |
| Workout Step (warmup) | `WorkoutKit.WorkoutStep` (warmup slot) | First Step of kind `.warmup` is hoisted into CustomWorkout's warmup slot |
| Workout Step (cooldown) | `WorkoutKit.WorkoutStep` (cooldown slot) | Last Step of kind `.cooldown` is hoisted into CustomWorkout's cooldown slot |
| Pace Range alert  | `WorkoutKit.SpeedRangeAlert`   | sec/km → m/s reciprocal: max speed = min pace                    |
| Heart Rate alert  | `WorkoutKit.HeartRateRangeAlert` | BPM range, `WorkoutAlertMetric.countPerMinute`                 |

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

## Example dialogue

> **Dev:** "When the user taps a **Pace Zone** chip in the Plan tab, what gets created?"

> **Coach:** "A fresh **Workout Template** named after the zone — '*Easy Run · 30 min*' — with a single **Workout Step** whose **Step Goal** is `time(30 min)` and whose **Step Alert** is a **Pace Range** resolved from the current **VDOT**."

> **Dev:** "Right, so the **Source** when it opens in **Workout Detail** is *Template*, not *Plan Session*?"

> **Coach:** "Correct. *Plan Session* is reserved for a real **Planned Session** from the active **Training Plan**. The Pace Zone shortcut is a generated **Template**, so the Detail page shows the Duplicate button so the user can save it to *Yours*."

> **Dev:** "And when they hit Start, the **Workout Template** becomes a `WorkoutKit.WorkoutPlan` — the first **Workout Step** of kind *Warm-up* gets hoisted into the WorkoutKit warmup slot?"

> **Coach:** "Yes. Everything in between becomes `IntervalBlock`s, the trailing *Cool-down* Step becomes the cooldown slot, and the Pace Range alert is translated to a `SpeedRangeAlert` in m/s."

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

### "Pace Zone" vs "Session Type"
Originally these were tangled — `SessionType.tempo` was used where `PaceZoneName.threshold`
was meant. The fix (commit `5284cc8`) introduced **PaceZoneName** as a separate
enum. **Session Type** classifies the *daily session* in a Training Plan
(Easy / Tempo / Interval / Long / Repetition / Rest); **Pace Zone** is the
Jack Daniels intensity used as a **Step Alert** (E / M / T / I / R).
They overlap conceptually but are not the same enum and **must not be conflated**
in code. The mapping for adapter conversions is hard-coded in
`PlanSessionAdapter` (e.g. `SessionType.tempo` → `PaceZoneName.threshold`).

### "Start"
"Start Workout" in the UI does NOT start a stopwatch in-app. It schedules the
Workout Template on the paired Apple Watch via `WorkoutScheduler.shared.schedule`.
The user must then open the Watch's Workout app to actually begin running.
**Recommendation:** when describing this action in PRs or docs, prefer
"Send to Apple Watch" over "Start" to avoid implying in-app timing.

### "Template"
Means two different things in the UI: the **Templates** segment (built-in
**Presets** only) and the underlying data type **Workout Template** (the
storage type for any saved or generated workout, presets included).
**Recommendation:** in code use **WorkoutTemplate**; in UI/PR copy say
"preset" when you mean the built-in fixtures and "template" only when you
mean the **Templates** segment specifically.
