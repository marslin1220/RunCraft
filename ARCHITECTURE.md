# RunCraft Architecture

> Complementary to [UBIQUITOUS_LANGUAGE.md](UBIQUITOUS_LANGUAGE.md). That file
> tells you _what the words mean_; this file tells you _how the system is wired_.

---

## 1. What RunCraft is

RunCraft turns Jack Daniels' VDOT methodology into a phone-and-watch experience:

- iPhone is the **architect** — race goal, 16-week periodised plan, workout
  authoring, training-pace lookups.
- Apple Watch is the **coach** — runs the structured workout the iPhone
  scheduled, enforces pace alerts during the session.

The iPhone app is built around four tabs — **Plan** (the dashboard),
**Workouts** (the workout library, internally still called `WorkshopFeature`
in code for historical reasons), **Insights** (VDOT and VO₂max trend,
weekly mileage, predicted race times), and **Settings**. Plan and Workouts
are connected by a one-way navigation delegate. All Apple-framework I/O
(HealthKit, WorkoutKit) sits behind TCA dependencies; all persistence sits
behind SQLiteData; all visual tokens (colours, dynamic light/dark variants)
live in `DesignSystem`.

Beyond the GUI, **RunCraftIntents** exposes four App Intents
(`WhatIsTodaysTrainingIntent`, `StartWorkoutIntent`, `AdjustVDOTIntent`,
`LogCompletedRunIntent`) so Siri, Spotlight, the Action button, and Apple
Intelligence can read and mutate plan state without launching the UI.

---

## 2. Architectural decisions

| Decision                                                  | Rationale                                                                                                              |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| **Local SPM package** as the bulk of the codebase         | The Xcode project is a thin shell: it owns the entitlements, Info.plist, and the `@main` entry. Everything else is SPM, so build times and module boundaries are explicit. |
| **The Composable Architecture** (TCA)                     | Every feature is a `@Reducer`. State changes are deterministic, effects are explicit, and tests use `TestStore` against a small interface. |
| **SQLiteData** with `@FetchAll` / `@FetchOne` in views    | Views observe queries directly; reducers write through repositories or via `@Dependency(\.defaultDatabase)`. JSON blobs are used only for nested authoring structures (Workout Blocks). |
| **One module per coherent responsibility**                | Splits domain (RunCraftModels), calculation (VDOTEngine), framework adapters (HealthKitClient, AppleWatchSync), and features (TrainingPlanFeature, WorkshopFeature). |
| **`@Dependency(\.healthKitClient)`, `@Dependency(\.watchConnectivityClient)`, `@Dependency(\.workoutTemplateRepository)`** | Apple-framework boundaries and persistence are seams. `liveValue` does the real work; `testValue` returns sensible no-ops or fakes so reducers can be exercised in isolation. |
| **Cross-tab navigation via `delegate` actions**           | A tab never reaches into another tab's state. Instead it emits a `delegate` case that the root `AppFeature` translates into a sibling tab's action. |
| **`DesignSystem` SPM target for design tokens**           | Every colour token resolves dynamically per `UIUserInterfaceStyle` via `UIColor(dynamicProvider:)`. Views never apply `.preferredColorScheme(.dark)` — system theme propagates. Light and dark variants are tuned for WCAG AA contrast independently. See [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). |

---

## 3. SPM module topology

```
                          ┌───────────────────────────────┐
                          │            RunCraft.app       │  RunCraftAppShortcuts
                          │       (Xcode app target)      │  registers Siri phrases
                          └──────────────┬────────────────┘
                                         │  imports
                                         ▼
                          ┌───────────────────────────────┐
                          │          AppFeature           │  Tab bar + Settings,
                          │      (root reducer)           │  cross-tab navigation
                          └────┬─────────┬─────────┬──────┘
                               │         │         │
        ┌──────────────────────┘         │         └──────────────────┐
        ▼                                ▼                            ▼
 ┌────────────────────┐    ┌─────────────────────────┐    ┌───────────────────┐
 │ TrainingPlanFeature│    │     WorkshopFeature     │    │  InsightsFeature  │
 │ Plan tab, ring,    │    │   "Workouts" tab,       │    │  Fitness trend    │
 │ adaptive banners,  │    │   editor, preset lib,   │    │  (VDOT/VO₂max/Δ), │
 │ This Week strip,   │    │   shared WorkoutEditor  │    │  weekly mileage,  │
 │ AdjustVDOT         │    │   (also pushed from     │    │  race predictions │
 └────┬─────────┬─────┘    │    Plan's stack)        │    └─────────┬─────────┘
      │         │          └──────┬──────────────────┘              │
      │         │                 │                                 │
      │         │ ┌───────────────┴─────────────────┐               │
      │         ▼ ▼                                 ▼               │
      │     ┌──────────────────┐         ┌────────────────────┐     │
      ├────►│  HealthKitClient │         │   AppleWatchSync   │     │
      │     │  workouts, HRV,  │◄────────┤   WorkoutKit +     │     │
      │     │  sleep, VO₂max   │         │   WorkoutPlanBuilder│    │
      │     └────────▲─────────┘         └────────┬───────────┘     │
      │              │                            │                 │
      │              │  also read by InsightsFeature                │
      │              └──────────────────────────────────────────────┘
      │
      │              ┌──────────────────────────────────────────────┐
      └─────────────►│              RunCraftIntents                  │◄──── AppFeature
                     │  AppEntities + AppIntents:                    │      re-exports
                     │  • WhatIsTodaysTrainingIntent                 │      via @_exported
                     │  • StartWorkoutIntent (param: template)       │
                     │  • AdjustVDOTIntent                           │
                     │  • LogCompletedRunIntent                      │
                     │  Each returns a SwiftUI snippet view.         │
                     └────────────────────────┬──────────────────────┘
                                              │
      ▼                                       ▼                     ▼
      ┌───────────────────────────────────────────────────────────────┐
      │                          RunCraftModels                       │
      │  @Table types · Schema migration · WorkoutTemplateRepository  │
      │  PlanSessionAdapter · VDOTSnapshot · TrainingWeek.current     │
      └──────────────────────────────┬────────────────────────────────┘
                                     │
                                     ▼
                          ┌────────────────────────────┐
                          │         VDOTEngine         │  Daniels formula +
                          │  PaceZoneName, PaceZones,  │  pace-zone derivation
                          │  VDOTCalculator,           │  + predicted race time
                          │  PaceUnit                  │
                          └────────────────────────────┘

   ┌────────────────────────────┐
   │       DesignSystem         │  Color.brand tokens (light/dark dynamic),
   │  Theme + WorkoutCard +     │  WorkoutCardPalette, TimeWheelPicker.
   │  TimeWheelPicker           │  Imported by every Feature target.
   └────────────────────────────┘

   ┌──────────────────────────────────────────────────────────────┐
   │              RunCraftWatch Watch App                          │  watchOS companion target:
   │  WatchAppDelegate    WorkoutSessionManager                    │  auto-starts via HKHealthStore,
   │  WatchHomeView (Sessions Wheel + Paces Wheel)                 │  runs interval state machine,
   │  ActiveWorkoutView   WorkoutStartView                         │  mirrors metrics to iPhone
   └──────────────────────────┬───────────────────────────────────┘
                               │  imports (SPM)
                               ├──► AppleWatchSync
                               └──► RunCraftModels
```

`DesignSystem` is a leaf UI-token module imported by every feature target.
It has no logic — just colour tokens (each with a light + dark variant),
the `WorkoutCard` Apple-Workout-style card, the shared `TimeWheelPicker`,
and the canonical `Color(hex:)` initialiser.

A `WatchAppFeature` target used to exist for an Apple Watch companion app,
but was removed once iPhone-side `WorkoutScheduler.shared.schedule()`
seemed sufficient (see commit `517c325`). On real hardware (watchOS 26.5)
that turned out not to be true — `WorkoutScheduler.schedule()` alone never
surfaces a workout on the Watch without a companion app. A much smaller
companion app, `RunCraftWatch`, was reintroduced to close that gap: its
job is to auto-start the workout (via `WKApplicationDelegate.handle(_:)`)
and run the full interval state machine with live metrics via HealthKit
Mirroring. See §4.4 and §4.4.1.

The arrows show **public** dependencies (declared in `Package.swift`).
Transitive deps reach further than the diagram shows — e.g. `WorkshopFeature`
sees `VDOTEngine` through `RunCraftModels`, but it still declares the import
explicitly when it uses `PaceZoneName` directly.

---

## 4. Module catalogue

### 4.1 VDOTEngine (3 files · 0 deps)

The deepest, smallest module. Pure Swift, no framework imports beyond
`Foundation`.

| File                  | Contains                                                              |
| --------------------- | --------------------------------------------------------------------- |
| `VDOTCalculator.swift`| `VDOTCalculator.vdot(distanceMeters:timeSeconds:)`, `paceZones(vdot:)`, `paceRange(for:vdot:)` — the Jack Daniels formula plus two derived lookups. |
| `PaceZones.swift`     | `PaceZones` struct (5 `PaceRange`s) + formatting helpers.             |
| `PaceZoneName.swift`  | The five-zone enum (E/M/T/I/R), `PaceZones[PaceZoneName]` subscript. |

**Interface depth.** Anyone asking "what pace should this runner hit?"
learns one type (`PaceZoneName`) and one call (`paceRange(for:vdot:)`).
Behind that, an O(1) lookup table-and-formula combination delivers
Daniels-published numbers at VDOT 40, vdoto2.com-calibrated numbers at
VDOT 31, and continuous interpolation in between (see commit `aab5f16`).

### 4.2 HealthKitClient (2 files · `Dependencies` only)

A TCA Dependency that wraps `HKHealthStore`. Live implementation queries
running workouts, HRV (`heartRateVariabilitySDNN`), sleep windows, and
VO₂max samples (`vo2Max`, unit `mL/(kg·min)` — directly comparable to
Daniels' VDOT). Test/preview values return canned data
(a 25-minute 5K → VDOT ≈ 40, empty VO₂max sample list).

The repository pattern is intentionally not used here: there is no
"local fake" use case — either HealthKit is present or it isn't.

### 4.3 RunCraftModels (12 files · VDOTEngine + SQLiteData + Dependencies + IdentifiedCollections)

The domain layer: tables, value types, the persistence repository, and the
two domain-pure converters.

```
RunCraftModels/
├── Tables/                     SQLiteData @Table types
│   ├── RaceGoal.swift          The user's chosen race
│   ├── TrainingWeek.swift      One of 16 weeks; + `current(in:at:)` static
│   ├── PlannedSession.swift    One day in a week
│   ├── CompletedWorkout.swift  A logged run linked to a PlannedSession
│   └── WorkoutTemplate.swift   Authoring artefact; blocks stored as JSON
├── Models/                     Pure value types
│   ├── TrainingPhase.swift     base/build/peak/taper
│   ├── SessionType.swift       easy/tempo/interval/long/repetition/rest
│   ├── RaceDistance.swift      Common distance helpers
│   └── WorkoutBlock.swift      Step | RepeatGroup + StepGoal + StepAlert
├── Schema.swift                `bootstrapDatabase()` + DatabaseMigrator
├── WorkoutTemplateRepository.swift  Save/load/all/delete TCA Dependency
└── PlanSessionAdapter.swift    PlannedSession → WorkoutTemplate (pure)
```

Two patterns are worth calling out:

**Workout Blocks as a JSON column.** `WorkoutTemplate` has the columns
`name`, `createdAt`, `updatedAt` + a `blocksData: String` column that
holds JSON-encoded `[WorkoutBlock]`. The decision was deliberate: blocks
are nested (a Repeat Group contains Steps), they're always loaded with
the parent template, and we never query across blocks. A relational
schema would have added two tables (`workoutBlocks`, `repeatGroupSteps`)
and a polymorphism layer for zero query-time benefit.

**`WorkoutTemplateRepository`.** A 4-closure struct (`save`, `load`,
`all`, `delete`) that's the only path to template persistence. `save`
internally decides INSERT vs UPDATE by looking up the id — callers
don't pass an "existing?" flag. `testValue` returns no-op defaults so
TestStore tests can exercise reducer logic without a real database.

### 4.4 AppleWatchSync (6 files · RunCraftModels + Dependencies)

The Apple Watch port. Shared by both the iPhone app and the
`RunCraftWatch` companion app (§4.4.1):

- **`WorkoutPlanBuilder` — pure conversion.** `makePlan(name:blocks:)`
  walks a `[WorkoutBlock]` and builds a WorkoutKit `CustomWorkout`. First
  `.warmup` step becomes the WorkoutKit warmup slot; last `.cooldown` step
  becomes the cooldown slot; everything in between becomes
  `IntervalBlock`s (a single `.step` → 1-iteration block; a Repeat Group →
  multi-iteration block). Pace alerts get reciprocal-converted from sec/km
  to m/s for WorkoutKit's `SpeedRangeAlert`. Gated behind
  `#if canImport(WorkoutKit)`.
- **`WatchWorkoutPayload` — shared wire DTO.** `{ name: String, subtitle:
  String?, blocks: [WorkoutBlock] }`, `Codable & Sendable & Equatable`,
  no `#if`. `subtitle` is optional (nil for editor payloads; populated with
  a pace-range string like "5:10 – 5:30 /km" for training-pace templates).
- **`WatchSchedulePayload` — schedule wire DTO.** Carries the current
  week's sessions (with `dayName`, `title`, `isToday`, and a nested
  `WatchWorkoutPayload`) plus five pace-zone quick-start templates.
  Sent via `WatchConnectivityClient.sendSchedule` and stored in
  `WCSession.receivedApplicationContext["schedule"]` so the Watch can
  read it immediately on launch.
- **`WatchConnectivityClient` — iOS-only TCA Dependency.** Wraps
  `WCSession`. `isWatchPaired()` checks `isPaired && isWatchAppInstalled`
  (not `isReachable` — the Watch need not be in Bluetooth range for the
  application context to work). `sendSchedule(payload)` JSON-encodes via
  `updateApplicationContext["schedule"]`. Note: `sendWorkout` was removed;
  workout payload delivery now happens inside `HKWatchTriggerClient` (below).
- **`HKWatchTriggerClient` — iOS-only TCA Dependency.** Combines two
  steps in one call: (1) writes `WatchWorkoutPayload` into
  `WCSession.updateApplicationContext[pendingWorkoutPayloadContextKey]`
  so the Watch can decode it in `handle(_:)`; (2) calls
  `HKHealthStore.startWatchApp(toHandle:)` to auto-launch `RunCraftWatch`.
  The Watch reads the payload from `receivedApplicationContext` (fast path)
  or `didReceiveApplicationContext` (slow path, with a 5-second
  `CheckedContinuation` timeout) before starting the session.
- **`LiveWorkoutClient` — iOS-only TCA Dependency.** Registers
  `HKHealthStore.workoutSessionMirroringStartHandler` to receive the
  mirrored session when the Watch starts. Exposes an
  `AsyncStream<LiveWorkoutEvent>` (`sessionStarted`, `messageReceived`,
  `sessionPaused`, `sessionResumed`, `sessionEnded`) and a
  `sendCommand(WorkoutMirrorCommand)` closure that relays pause/resume/end
  to the Watch via `HKWorkoutSession.sendToRemoteWorkoutSession(data:)`.
  Subscribed at app launch from `AppFeature.onTask`.
- **`WorkoutMirrorMessage` / `WorkoutMirrorCommand` — shared wire types.**
  `WorkoutMirrorMessage` (Watch → iPhone): step name, goal text, progress,
  HR, pace, metres, elapsed seconds, `isPaused`. `WorkoutMirrorCommand`
  (iPhone → Watch): `pause` / `resume` / `end`. Both are `Codable & Sendable & Equatable`
  and carry no platform guards — used by both sides.

#### 4.4.1 RunCraftWatch (native Xcode app target)

A full-featured watchOS companion app at `/RunCraftWatch Watch App/`,
linking `AppleWatchSync` + `RunCraftModels` SPM products. Requires the
`com.apple.developer.healthkit` + `com.apple.security.application-groups`
entitlements (the App Group shares the `paceUnit` preference with the
iPhone).

Key files:

| File                          | Role                                                                 |
| ----------------------------- | -------------------------------------------------------------------- |
| `RunCraftWatchApp.swift`      | `@main`; `@WKApplicationDelegateAdaptor(WatchAppDelegate.self)`. Routes between `WatchHomeView` and `ActiveWorkoutView` based on `manager.phase`. |
| `WatchAppDelegate.swift`      | `WKApplicationDelegate + WCSessionDelegate`. Activates `WCSession` on launch; decodes `"schedule"` from `receivedApplicationContext`; handles `HKWorkoutConfiguration` delivered by `HKHealthStore.startWatchApp(toHandle:)`. Uses a `CheckedContinuation<WatchWorkoutPayload?, Never>` for the slow-path payload race (5-second timeout). Calls `startMirroringToCompanionDevice()` before `startActivity(with:)` + `beginCollection(at:)` (Apple's required order). |
| `WorkoutSessionManager.swift` | `@MainActor ObservableObject`. Owns `HKWorkoutSession + HKLiveWorkoutBuilder`. Runs an interval state machine: flattens blocks → `[(WorkoutStep, displayName)]`; time steps advance via a 0.5 s Task loop; distance steps advance via `HKLiveWorkoutBuilderDelegate`. Published: `phase`, `elapsedSeconds`, `heartRate`, `paceSecPerKm`, `totalMetres`, `stepName`, `stepGoalText`, `stepProgress`. Sends `WorkoutMirrorMessage` to iPhone via `session.sendToRemoteWorkoutSession(data:)` on each step change and metric update; receives `WorkoutMirrorCommand` (pause / resume / end) from iPhone. Pace and distance display respects `paceUnit` from the shared App Group. |
| `WatchHomeView.swift`         | Navigation shell shown when `phase == .inactive`. Outer `TabView(.page)` with two wheel pages: **Sessions Wheel** (this week's sessions, today-first sorted, vertical scroll with scale + opacity `scrollTransition`) and **Paces Wheel** (five pace-zone quick-starts with pace-range subtitles). Falls back to a "sync on iPhone" prompt when no schedule. |
| `ActiveWorkoutView.swift`     | `TabView(.page)`. Metrics page: step name + `ProgressView` + goal text + HR / Pace / Dist / Time grid. Controls page: Pause/Resume + End with confirmation. |
| `WorkoutStartView.swift`      | Tapped from `WatchHomeView`. Shows workout name + step list + Start button. Requests HK auth, creates `HKWorkoutSession`, calls `workoutManager.startWorkout(session:blocks:healthStore:)` (same path as the HK-triggered auto-start). |

**Two workout start paths share the same `startWorkout` entry point:**

1. **iPhone-triggered auto-start.** iPhone calls `HKWatchTriggerClient.startWatchSession(payload)` → writes payload to WCSession context + calls `HKHealthStore.startWatchApp(toHandle:)` → system delivers `HKWorkoutConfiguration` to `WatchAppDelegate.handle(_:)` → reads blocks from `receivedApplicationContext[pendingWorkoutPayloadContextKey]` → starts session via `WorkoutSessionManager.startWorkout(session:blocks:healthStore:)`.
2. **Watch standalone.** User opens `RunCraftWatch`, taps a session in `WatchHomeView` → `WorkoutStartView` → taps Start → creates `HKWorkoutConfiguration` locally → starts session via the same `WorkoutSessionManager.startWorkout`.

**iPhone live workout mirror.** `AppFeature` subscribes to `liveWorkoutClient.events()` at launch. When the Watch starts a mirrored session, `LiveWorkoutClient` fires `.sessionStarted`; `AppFeature` sets `state.liveWorkout = LiveWorkoutDisplay()` and `AppView` shows `LiveWorkoutView` as a `.fullScreenCover`. Subsequent `WorkoutMirrorMessage` packets update step name, progress, HR, pace, and distance in real time. `LiveWorkoutView` sends `WorkoutMirrorCommand` (pause / resume / end) back to the Watch. On `.sessionEnded`, the final message's metrics (distance, time, avg pace, avg HR) are captured into `state.completionSummary`; `AppView` then shows `WorkoutCompletionView` as a `.sheet` so the runner sees an immediate summary. Dismissing the sheet clears `completionSummary`.

### 4.5 TrainingPlanFeature (7+ files · VDOTEngine + HealthKitClient + RunCraftModels + AppleWatchSync + WorkshopFeature + DesignSystem + ComposableArchitecture)

The Plan tab.

| File                            | Role                                                          |
| ------------------------------- | ------------------------------------------------------------- |
| `TrainingPlanFeature.swift`     | Root reducer for the Plan tab; emits delegate actions to AppFeature. |
| `SetupRaceGoalFeature.swift`    | Onboarding sheet — VDOT detection (HealthKit) or race-time entry. |
| `TrainingPlanGenerator.swift`   | Pure function: race goal + VDOT → 16 weeks × 7 sessions.      |
| `Views/PlanView.swift`          | Dashboard: countdown ring, This Week strip, pace chips, full-schedule destination. |
| `Views/SetupRaceGoalView.swift` | The onboarding form.                                          |

**Dashboard hierarchy.** Top-down: compact HStack countdown (120pt ring
+ goal name / phase / date), banners (VDOT upgrade, recovery advice),
**This Week** session strip (today's card carries a play-button
quick-start), then pace-zone chips at the bottom. The week strip sits
**above** the pace chips because the runner's daily question is "what
do I run today?" — paces are reference data, the schedule is the
action. Apple Workout follows the same hierarchy.

**Pre-plan period.** When the race is more than 16 weeks out,
`TrainingWeek.current(in:)` returns nil. `PlanView.firstUpcomingWeek`
picks the earliest week whose `startDate` is still in the future, and
`PrePlanPreviewSection` renders a caution-tinted "Plan starts in N
days" banner plus a 55%-opacity preview of week 1 (rest days omitted).
The preview rows are read-only — no quick-start, no tap-into-editor —
because those sessions live in the future.

**Cross-tab delegate.** `TrainingPlanFeature.Action` includes a
`delegate(.openWorkoutInWorkshop(WorkoutTemplate, source))` case. The
Plan tab emits it when the user taps a pace chip, a day in this week's
list, or a day in the full-schedule destination. AppFeature catches it
(see §5.4).

### 4.6 WorkshopFeature (9 files · AppleWatchSync + VDOTEngine + RunCraftModels + ComposableArchitecture + IdentifiedCollections + SQLiteData)

The Workshop tab. The largest feature module; it now houses authoring
plus the navigation shell.

```
WorkshopFeature/
├── WorkshopFeature.swift          Shell: segment picker, navigation StackState
├── WorkoutDetailFeature.swift     Read-only detail page reducer + Source enum
├── WorkoutEditorFeature.swift     Authoring reducer + EditStep + EditRepeatGroup
├── WorkoutPresets.swift           Five built-in workouts (Yasso 800s, ...)
└── Views/
    ├── WorkshopView.swift         List + Yours/Templates/Plan segments
    ├── WorkoutDetailView.swift    Block preview + Start button
    ├── WorkoutEditorView.swift    Drag-and-drop editor + name bar
    ├── EditStepSheet.swift        Step parameter sheet (with pace-zone shortcuts)
    └── EditRepeatGroupSheet.swift Repeat group sheet (iterations stepper)
```

Three reducers sit at three navigation depths:

1. **`Workshop`** — list shell. `StackState<Path>` with two destinations
   (`.detail`, `.editor`). Owns the segment selection.
2. **`WorkoutDetail`** — read-only block preview. Emits delegate
   actions (`requestEdit`, `requestDuplicate`) for the shell to handle.
3. **`WorkoutEditor`** — authoring. Uses
   `@Dependency(\.workoutTemplateRepository)`; no direct SQL.

Two sheet reducers (`EditStep`, `EditRepeatGroup`) sit inside the editor.

### 4.7 AppFeature (6 files · TrainingPlanFeature + WorkshopFeature + AppleWatchSync + ComposableArchitecture)

The root.

| File                        | Role                                                       |
| --------------------------- | ---------------------------------------------------------- |
| `AppFeature.swift`          | Tab enum, root reducer composing Plan / Workshop / Settings. Subscribes to `liveWorkoutClient.events()` via `.onTask`; updates `state.liveWorkout` with live metrics; sends `WorkoutMirrorCommand` back to Watch. |
| `AppView.swift`             | `TabView` with the four tabs (Plan / Workouts / Insights / Settings). Shows `LiveWorkoutView` as a `.fullScreenCover` when `store.liveWorkout != nil`. |
| `LiveWorkoutView.swift`     | iPhone live workout overlay. Step card with `ProgressView`, 2×2 metrics grid (HR / Pace / Dist / Time), Pause/Resume/End controls. Reads `paceUnit` from the App Group to format pace and distance. |
| `SettingsFeature.swift`     | Settings reducer — minimal today (just an `onAppear`). HealthKit linking is intentionally **not** in Settings: per HIG, authorisation is requested at point-of-use (Setup Race Goal's Auto-detect button), not pre-emptively from a Settings toggle. |
| `SettingsView.swift`        | Settings form. Pace unit Picker writes directly to `@AppStorage("paceUnit")` so the bind sidesteps a BindingReducer + `@Shared` quirk; every other view reads via `@Shared(.appStorage("paceUnit"))`. |
| `Bootstrap.swift`           | `makeAppStore()` (`@MainActor`) + `bootstrapApp()` (calls `prepareDependencies { try! $0.bootstrapDatabase() }`). |

### 4.8 InsightsFeature (2 files · HealthKitClient + RunCraftModels + VDOTEngine + ComposableArchitecture + SQLiteData)

The Insights tab. Reducer loads three series in parallel via
`async let`: `VDOTSnapshot` history from SQLiteData (one row per VDOT
change, sourced as `initial` / `raceTime` / `overperformance` / `manual`),
recent `CompletedWorkout` rows, and the last 180 days of HealthKit
VO₂max samples. VO₂max fetch failures are swallowed so the rest of
the tab still loads.

The view renders three cards:

1. **Fitness trend** — segmented `Picker` (VDOT / VO₂max / Δ) drives a
   shared hero number + chart pane. The three series are peers, not
   stacked: putting them in one card prevents users from treating VDOT
   and VO₂max as separate goals. The Δ series is computed lazily on
   `State.deltaSeries` — for each VDOT snapshot, picks the nearest
   VO₂max sample at or before that date and emits the difference.
   Snapshots without a VO₂max counterpart are skipped (don't fabricate
   zeros). Picker selection lives on `State.selectedTrend: TrendKind`
   via `BindingReducer`.
2. **Weekly mileage** — last 8 weeks of completed-workout distance
   as a bar chart.
3. **Predicted race times** — 5K / 10K / HM / Marathon, computed via
   `VDOTCalculator.predictedTime(distanceMeters:vdot:)` (iterative
   inversion of the Daniels formula).

### 4.9 DesignSystem (3 files · 0 deps)

UI tokens only. No logic, no state.

| File                  | Contains                                                              |
| --------------------- | --------------------------------------------------------------------- |
| `Theme.swift`         | `Color.brand.*` tokens (background, surface, textPrimary, textSecondary, accent, success, caution, danger, zone.*) — each resolves dynamically via `UIColor(dynamicProvider:)`. Plus `WorkoutCardPalette` and the canonical `Color(hex:)` initialiser. |
| `WorkoutCard.swift`   | The Apple-Workout-style card component used by Plan tab and Workouts list. Tinted background + leading SF Symbol + trailing Play / Chevron / Check. |
| `TimeWheelPicker.swift` | Two-wheel minute/second picker shared between `EditStepSheet` and `SetupRaceGoalView`. |

### 4.10 RunCraftIntents (7 files · DesignSystem + AppleWatchSync + RunCraftModels + VDOTEngine + WorkshopFeature + SQLiteData + Dependencies)

The voice / Spotlight / Apple-Intelligence surface. Four intents + two
queries + four SwiftUI snippet views.

| File                              | Role                                                          |
| --------------------------------- | ------------------------------------------------------------- |
| `TodaySessionEntity.swift`        | `AppEntity` for "today's planned session" — singleton id `"today"`. |
| `TodaySessionQuery.swift`         | Reads current `TrainingWeek` + day-of-week from SQLiteData and joins the latest VDOT for live paces. |
| `WhatIsTodaysTrainingIntent.swift`| Voice phrase: "What's today's training in RunCraft". Returns dialog + snippet. |
| `WorkoutTemplateEntity.swift`     | `AppEntity` covering both built-in presets and user-saved templates. |
| `WorkoutTemplateQuery.swift`      | `EntityStringQuery` — name-fuzzy lookup so "Yasso" / "Mona" / "Recovery" resolves. |
| `StartWorkoutIntent.swift`        | `@Parameter var workout` → `hkWatchTriggerClient.startWatchSession(WatchWorkoutPayload(...))` (writes WCSession context + calls `startWatchApp(toHandle:)`). |
| `AdjustVDOTIntent.swift`          | `@Parameter var vdot: Double` (30–85). Writes `RaceGoal.currentVDOT` + a `VDOTSnapshot(source: .manual)`. |
| `LogCompletedRunIntent.swift`     | Conversational refinement — Siri asks for distance + duration; writes a `CompletedWorkout`. |
| `*SnippetView.swift`              | Static SwiftUI snippets rendered inline in Siri / Spotlight responses. |

**Module placement.** `AppShortcutsProvider` *must* live in the app
target (iOS scans the main bundle at install time), but the intents
themselves live in this SPM target. `AppFeature/Bootstrap.swift` does
`@_exported import RunCraftIntents`, so the app target's
`RunCraftAppShortcuts.swift` sees the intent types through `AppFeature`
without an explicit `import RunCraftIntents`. This avoids touching
`.pbxproj` to add a second framework dependency.

**Sendable workaround.** `EntityQuery` requires `Self: Sendable`, but
applying the `@Dependency` macro inside a `Sendable` struct triggers a
Swift compiler internal panic (`failed to produce diagnostic for
expression`). Workaround: instantiate the wrapper directly with
`Dependency(key: \DependencyValues.X).wrappedValue` — same runtime,
no macro expansion. See `TodaySessionQuery.currentDatabase()` and
`StartWorkoutIntent.perform()` for the pattern.

**iOS 26 `view:` overload.** The `result(dialog:view:)` /
`result(dialog:) { content }` overloads that combine a dialog with a
SwiftUI snippet live in the `_AppIntents_SwiftUI` cross-import overlay.
Files using snippets must `import AppIntents` **and** `import SwiftUI`.

---

## 5. Core patterns

### 5.1 The Composable Architecture composition

Each tab is its own `@Reducer`. `AppFeature` composes them with `Scope`s:

```swift
public var body: some Reducer<State, Action> {
    Scope(state: \.plan,     action: \.plan)     { TrainingPlan() }
    Scope(state: \.workshop, action: \.workshop) { Workshop() }
    Scope(state: \.settings, action: \.settings) { Settings() }
    Reduce { state, action in
        switch action {
        case let .tabSelected(tab): state.selectedTab = tab; return .none
        case let .plan(.delegate(.openWorkoutInWorkshop(template, source))):
            state.selectedTab = .workshop
            return .send(.workshop(.openDetail(template, mapSource(source))))
        case .plan, .workshop, .settings: return .none
        }
    }
}
```

Inside a feature, presentation uses `@Presents`; nested navigation
inside a feature uses `StackState`.

```
Workshop                                 TrainingPlan
├── @ObservableState State              ├── @ObservableState State
│   ├── selectedSegment: Segment        │   ├── hasGoal: Bool
│   └── path: StackState<Path.State>    │   ├── paceZones: PaceZones?
│                                       │   ├── path: StackState<Path.State>
└── Path                                │   └── @Presents destination
    ├── .detail(WorkoutDetail)          │
    └── .editor(WorkoutEditor)          ├── Path: .weekSchedule(WeekSchedule)
                                        │
                                        └── Destination
                                            ├── .setupRaceGoal(SetupRaceGoal)
                                            └── .deleteConfirm(AlertState)
```

### 5.2 SQLiteData persistence

There are two flavours of database access:

- **Reducer-side writes go through repositories.** `WorkoutEditor`
  uses `@Dependency(\.workoutTemplateRepository)`; the live value
  calls `database.write { ... }`. No reducer imports SQLiteData
  directly any more.
- **View-side reads use `@FetchAll` / `@FetchOne`.** Views observe
  queries that update automatically when underlying tables change.
  Example from `WorkshopView`'s Plan segment:

  ```swift
  @FetchOne(RaceGoal.order { $0.createdAt.desc() }) var goal: RaceGoal?
  @FetchAll var allWeeks: [TrainingWeek]
  @FetchAll(PlannedSession.none) var thisWeekSessions: [PlannedSession] = []

  private var currentWeek: TrainingWeek? {
      TrainingWeek.current(in: allWeeks)
  }
  ```

The schema is set up once in `RunCraftModels/Schema.swift`. Tables use
SQLite `STRICT` mode; dates are stored as ISO 8601 `TEXT` (because GRDB
serialises `Date` that way — see commit notes). Block trees in
`WorkoutTemplate` are stored as JSON.

`Bootstrap.swift` calls `prepareDependencies { try! $0.bootstrapDatabase() }`
in the app's `init`. In `#DEBUG`, `eraseDatabaseOnSchemaChange = true` so
migrations are forgiving during development.

### 5.3 Dependency injection: live / test / preview

Three Dependencies wrap framework or persistence I/O:

| Dependency                          | Module           | Live target                                                |
| ----------------------------------- | ---------------- | ---------------------------------------------------------- |
| `\.healthKitClient`                 | HealthKitClient  | `HKHealthStore` queries (workouts, HRV, sleep)             |
| `\.watchConnectivityClient`         | AppleWatchSync   | `WCSession.updateApplicationContext` (schedule sync)       |
| `\.hkWatchTriggerClient`            | AppleWatchSync   | Writes WCSession context + `HKHealthStore.startWatchApp(toHandle:)` |
| `\.liveWorkoutClient`               | AppleWatchSync   | `HKHealthStore.workoutSessionMirroringStartHandler` — iPhone-side metrics stream |
| `\.workoutTemplateRepository`       | RunCraftModels   | `database.write/read { ... }` via SQLiteData               |

Each provides a `testValue` that returns sensible defaults; reducers'
`TestStore` tests override only the closures they care about. Example
from `WorkoutEditorPersistenceTests`:

```swift
let store = TestStore(initialState: makeStateWithBlocks()) {
    WorkoutEditor()
} withDependencies: {
    $0.uuid = .constant(newId)
    $0.date.now = fixedDate
    $0.workoutTemplateRepository = .testValue
    $0.workoutTemplateRepository.save = { @Sendable template in
        await captured.set(template)
        return template.id
    }
}
```

### 5.4 Cross-tab navigation via delegate cascade

When the Plan tab needs to push a workout in the Workshop tab:

```
PlanView
  user taps a session in WeekSessionsSection or WeekScheduleView
    │
    ▼
TrainingPlan.Action.sessionTapped(session)
    │
    ▼   (in TrainingPlan reducer)
.delegate(.openWorkoutInWorkshop(template, source))
    │
    ▼   (parent: AppFeature reducer)
state.selectedTab = .workshop
.send(.workshop(.openDetail(template, mappedSource)))
    │
    ▼   (Workshop reducer)
state.path.removeAll()
state.path.append(.detail(WorkoutDetail.State(workout: template, source: source)))
    │
    ▼
TabView switches; user lands on WorkoutDetailView with the workout pre-loaded
```

Neither tab knows about the other. AppFeature is the only place that
sees both. Adding a third tab that wants to trigger Workshop navigation
would add one case to AppFeature's switch, nothing else.

### 5.5 iPhone → Watch workout dispatch + live mirror

The path from "user taps Start" to "workout auto-starts on the wrist" and
live metrics flowing back to the iPhone:

```
WorkoutEditor.Action.startTapped                          (iPhone)
    │
    └─▶ hkWatchTriggerClient.startWatchSession(WatchWorkoutPayload)
            ├─ WCSession.updateApplicationContext[pendingWorkoutPayloadContextKey] = jsonData
            └─ HKHealthStore.startWatchApp(toHandle: HKWorkoutConfiguration)
                    │
                    ▼   ──────────────────────────────── (paired Apple Watch)
            WatchAppDelegate.handle(_ config: HKWorkoutConfiguration)
                    │
                    ├─ reads blocks: WCSession.receivedApplicationContext[key]
                    │   (fast path) or awaits didReceiveApplicationContext
                    │   via CheckedContinuation, 5-second timeout
                    └─▶ WorkoutSessionManager.startWorkout(session:blocks:healthStore:)
                                │
                                ├─ startMirroringToCompanionDevice()   ← mirroring first
                                ├─ session.startActivity(with:)
                                ├─ builder.beginCollection(at:)        ← then collection
                                ├─ flattenBlocks → [(WorkoutStep, displayName)]
                                │   ├─ distance steps: HKLiveWorkoutBuilderDelegate
                                │   └─ time steps: 0.5s Task loop
                                └─▶ ActiveWorkoutView (watch-side metrics + controls)

    ◀──────────────────────────── WorkoutMirrorMessage (Watch → iPhone) ──────────────
    │   stepName, stepGoalText, stepProgress, heartRate, paceSecPerKm,
    │   totalMetres, elapsedSeconds, isPaused
    │   (sent via HKWorkoutSession.sendToRemoteWorkoutSession on each update)
    │
    ▼   (AppFeature via LiveWorkoutClient.events())
AppFeature.State.liveWorkout = LiveWorkoutDisplay(message: msg)
    │
    └─▶ AppView shows LiveWorkoutView (.fullScreenCover)
            │
            ├─ metrics grid: HR / Pace / Dist / Time
            ├─ step card with ProgressView
            └─ Pause / Resume / End buttons
                    │
    ──────────────────▶ WorkoutMirrorCommand (iPhone → Watch)
                        (pause / resume / end)

                        Workout ends (auto or manual on Watch)
                                │
                        LiveWorkoutEvent.sessionEnded → state.liveWorkout = nil
                        builder.finishWorkout() → HKWorkout saved
                                │
                        TrainingPlanFeature.syncBackWorkouts picks it up ✓
```

The reducer never imports HealthKit. `WorkoutSessionManager` is watchOS-only
and never touches TCA — it's a plain `ObservableObject` owned by
`WatchAppDelegate`. `LiveWorkoutClient` is the iPhone counterpart, living
inside `AppleWatchSync` and exposed as a TCA dependency to `AppFeature`.

---

## 6. Data flow walk-throughs

### 6.1 First launch — create a race goal

1. `RunCraftApp.init` calls `bootstrapApp()`. Database opens; migration
   creates 5 tables.
2. `AppView` renders the Plan tab. `PlanView.onAppear` sends
   `.onAppear` → reducer queries `RaceGoal.all.fetchCount(db)`.
3. No goal exists. `state.hasGoal = false`. `EmptyPlanPrompt` shows a
   "Create Race Goal" button.
4. Tap → `.createGoalButtonTapped` → `state.destination = .setupRaceGoal(...)`.
5. User picks 5K + 25 min, taps Save. `SetupRaceGoal` reducer
   computes VDOT, creates a `RaceGoal`, calls
   `TrainingPlanGenerator.generate(goal:vdot:)` for 16 weeks × 7 sessions,
   writes everything in one transaction, dismisses the sheet.
6. Sheet dismissal triggers `.destination(.dismiss)` in `TrainingPlan`.
   Reducer re-runs `.onAppear`; this time `hasGoal = true` and it kicks
   off `.fetchVDOTTapped`.
7. Plan tab now shows the countdown ring, pace chips (E/M/T/I/R), and
   this week's session cards.

### 6.2 Tap a Plan session → run it on the watch

1. User taps Wednesday's "Tempo · 8 km" card in PlanView's
   `WeekSessionsSection`.
2. `TrainingPlan` reducer receives `.sessionTapped(session)`. It calls
   `PlanSessionAdapter.makeTemplate(from: session, vdot: state.currentVDOT)`
   to get a runnable `WorkoutTemplate` (warmup + tempo on 70% of distance
   + cooldown, pace alerts derived from current VDOT).
3. Emits `.delegate(.openWorkoutInWorkshop(template, .planSession))`.
4. `AppFeature` catches the delegate, switches `selectedTab = .workouts`,
   sends `.workouts(.openDetail(template, .planSession))`.
5. `Workshop` reducer clears its path and pushes `.editor(...)`.
6. TabView animates to Workouts; user sees `WorkoutEditorView` with the
   block list and a green "Start Workout" button.
7. Tap Start → `.startTapped` → calls
   `hkWatchTriggerClient.startWatchSession(payload)`: writes payload to
   `WCSession.updateApplicationContext[pendingWorkoutPayloadContextKey]`,
   then calls `HKHealthStore.startWatchApp(toHandle:)`.
8. System auto-launches `RunCraftWatch` on the Watch.
   `WatchAppDelegate.handle(_:HKWorkoutConfiguration)` fires, reads blocks
   from `receivedApplicationContext` (or awaits the slow-path via
   `CheckedContinuation`), calls `workoutManager.startWorkout(session:blocks:healthStore:)`.
9. `ActiveWorkoutView` appears on the Watch — step name, progress, HR, pace,
   distance. Intervals advance automatically when time/distance goals are met.
   `syncStatus = .sent` on the iPhone ("Starting on your Apple Watch…").
10. As the Watch workout runs, `WorkoutMirrorMessage` packets flow to the
    iPhone via HealthKit Mirroring. `AppFeature.liveWorkoutEvent(.messageReceived)`
    updates `liveWorkout.message`. `AppView` shows `LiveWorkoutView` as a
    full-screen cover with live HR, pace, distance, and elapsed time. User
    can pause/resume/end from iPhone or Watch — commands round-trip via
    `WorkoutMirrorCommand`.
11. Workout ends (auto when final step completes, or manual). `builder.finishWorkout()`
    saves an `HKWorkout`. `LiveWorkoutEvent.sessionEnded` dismisses
    `LiveWorkoutView`. On next iPhone foreground, `TrainingPlan.syncBackWorkouts`
    imports the workout as a `CompletedWorkout`.

### 6.3 Save a preset as your own

1. Workshop tab → Templates segment → tap "Yasso 800s".
2. `Workshop.workoutTapped(template, .template)` → push
   `.detail(WorkoutDetail.State(workout: yasso, source: .template))`.
3. Detail page renders. Because `source != .yours`, the toolbar shows
   a Duplicate icon.
4. Tap Duplicate → `WorkoutDetail.duplicateTapped` →
   `.delegate(.requestDuplicate(template))`.
5. `Workshop` reducer catches the delegate. Mints a new UUID, creates
   a `WorkoutTemplate` copy named "Yasso 800s copy", switches the
   segment back to Yours, clears the path, calls
   `repository.save(copy)`.
6. The Yours segment's `@FetchAll` observes the row appearing and
   re-renders. User sees their copy.

---

## 7. Build & test

### 7.1 Package.swift surface

```swift
products: [
    .library(name: "VDOTEngine",          targets: ["VDOTEngine"]),
    .library(name: "HealthKitClient",     targets: ["HealthKitClient"]),
    .library(name: "RunCraftModels",      targets: ["RunCraftModels"]),
    .library(name: "TrainingPlanFeature", targets: ["TrainingPlanFeature"]),
    .library(name: "AppleWatchSync",      targets: ["AppleWatchSync"]),
    .library(name: "WorkshopFeature",     targets: ["WorkshopFeature"]),
    .library(name: "InsightsFeature",     targets: ["InsightsFeature"]),
    .library(name: "DesignSystem",        targets: ["DesignSystem"]),
    .library(name: "AppFeature",          targets: ["AppFeature"]),
    .library(name: "RunCraftIntents",     targets: ["RunCraftIntents"]),
],
```

Five test targets:

| Test target               | Surface                                                          |
| ------------------------- | ---------------------------------------------------------------- |
| `VDOTEngineTests`         | Daniels formula reference points; `paceRange(for:vdot:)` parity; iteration safety. |
| `RunCraftModelsTests`     | `PlanSessionAdapter` (13 tests, branch coverage); `TrainingWeek.current` boundary tests; `WorkoutSyncBack` mapping. |
| `TrainingPlanFeatureTests`| `TrainingPlanGenerator` periodisation structure.                 |
| `WorkshopFeatureTests`    | `EditStep` validation, `WorkoutEditor` persistence via fake repository. |
| `AppleWatchSyncTests`     | `WorkoutPlanBuilder` warmup hoisting, repeat-group iterations, and `makePlan(name:blocks:)` parity with `makePlan(from:)`. |

### 7.2 The "no transitive deps in test targets" rule

Per the [pfw-testing](https://github.com/pointfreeco) guidance, a test
target links only the module it tests. ComposableArchitecture,
SQLiteData, Dependencies etc. arrive transitively. Linking them
explicitly causes objc runtime "class implemented in two places"
warnings.

### 7.3 Running tests

Two paths:

- **Xcode UI** (Cmd-U) — opens the test plan; works for every target.
- **`xcodebuild test`** — works if the test target is added to the
  RunCraft scheme. The package's per-target schemes (e.g.
  `VDOTEngine`, `RunCraftModels`) are not auto-configured for the
  test action; that requires a manual Edit Scheme.

`swift test` from the package root **does not work** because the
SwiftPM build covers all targets including iOS-only views. The host
is macOS, and SwiftUI APIs used by the views are unavailable on
macOS host.

---

## 8. Open questions and future work

Moved to [`TODOS.md`](TODOS.md) — deliberately-deferred items with the
reasoning behind each deferral.

---

## 9. Provenance

This architecture was hardened through a six-candidate review in early
June 2026. The review HTML report lived in `$TMPDIR` and is now gone;
the resulting commits are the durable artefact:

| Candidate                                     | Commit     |
| --------------------------------------------- | ---------- |
| #3 Delete vestigial `TemplateLibrarySheet`    | `27de8b0`  |
| #4 Cover `PlanSessionAdapter` with tests      | `d7e5ccd`  |
| #1 Extract `WorkoutTemplateRepository` seam   | `f43bbda`  |
| #2 Deepen VDOTEngine with `PaceZoneName`      | `63839b7`  |
| #5 Single source of truth for current week    | `99de872`  |
| #6 Carve `AppleWatchSync` out of WorkshopFeature | `9c44e05` |

Read [UBIQUITOUS_LANGUAGE.md](UBIQUITOUS_LANGUAGE.md) before opening a PR
that introduces new domain terms.
