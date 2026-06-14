# Flexible Training Days — Design

> Explains *why* `TrainingPlanGenerator` schedules sessions the way it
> does once a runner restricts which weekdays they can train. The code
> lives in
> `RunCraftPackage/Sources/TrainingPlanFeature/TrainingPlanGenerator.swift`,
> exhaustively tested by `FlexibleTrainingDaysTests` (all 127 non-empty
> subsets of weekdays × all 4 phases). If this doc disagrees with the
> code, the code wins and this doc needs updating.

## Inputs

- `availableDays: Set<Int>` — weekdays the runner can train, `1...7` =
  Mon...Sun. Defaults to all 7.
- `longRunDay: Int?` — the runner's preferred day for the long run,
  honored when it's in `availableDays`.

These are orthogonal to `TrainingPhase` (base/build/peak/taper) and to
the weekly-km periodization curve (`weeklyKm`) — they only affect
**which day each session lands on, and how many sessions exist**, not
the volume targets themselves.

---

## The maintenance-mode threshold: 1 vs 2+ days

### Decision

- `availableDays.count <= 1` → **maintenance mode**. The week gets
  exactly one session: `.easy`, 5 km, `.easy` zone — every phase,
  every week, on the single available day. `TrainingPhase` is ignored
  entirely.
- `availableDays.count >= 2` → the full periodized placement algorithm
  runs (required + optional sessions, phase-aware, described below).

### Why 1 is the floor

Periodization is a statement about the *relationship* between sessions
in a week — a long run next to easy days, a quality session balanced
against recovery. With only one session, there's nothing for it to
relate to, so "phase-aware" scheduling degenerates into picking a
single number and pretending it means something:

- **Picking the phase's top-priority session** (long run for
  base/build/peak, tempo/interval for taper) means the one weekly run
  swings from a 14–24 km long run to an 8 km tempo and back, with zero
  supporting volume either way. For a runner who can only commit to
  one day a week, a standalone 14 km+ effort is a progression risk,
  not a benefit.
- **Picking anything else** is arbitrary — there's no "this week's
  theme" for a single run to express when every other day is rest.

Below the 2-session floor, the goal quietly changes from *"optimize
training stimulus"* to *"keep the runner moving, safely, every week of
the 16."* A flat 5 km easy run is appropriate regardless of where the
runner sits in the 16-week arc, and doesn't require them to understand
periodization to follow it.

### Why 2 is enough

At `availableDays.count == 2`, `requiredSessionSpecs(for: phase)` is
consulted and `usedRequired = Array(required.prefix(min(required.count, days.count)))`
gives exactly the top 2 phase-defining sessions with **zero** optional
fillers:

| Phase | The 2 sessions a 2-day runner gets |
| ----- | ----------------------------------- |
| Base  | Long run (14 km, E) + R strides (5 km) |
| Build | Long run (18 km, E) + Tempo (10 km, T) |
| Peak  | Long run (24 km, E) + Interval (10 km, I, 5×1000m) |
| Taper | Tempo (8 km, T) + Interval (6 km, I, 3×1000m) — no long run |

That's the minimum *skeleton* that still differs phase-to-phase — two
sessions that play different roles (volume vs. quality, or two
distinct qualities in taper) is the smallest unit periodization can
express. 3+ days layer on additional required sessions (Build/Peak
have 3) and then up to 3 easy fillers; see the worked table below.

---

## Required vs. optional sessions per phase

`requiredSessionSpecs(for:)` is priority-ordered — the long run (when
present) is always first, and the *lowest*-priority entries are the
first dropped when `availableDays.count` is small.

| Phase | Required (priority order) | Optional fillers (`.easy`, in order) |
| ----- | --------------------------- | ------------------------------------- |
| Base  | Long 14km(E) → R-strides 5km | 6, 8, 10 km |
| Build | Long 18km(E) → Tempo 10km(T) → Tempo 8km(T) | 8, 8, 8 km |
| Peak  | Long 24km(E) → Interval 10km(I, 5×1000m) → Tempo 10km(T) | 8, 8, 6 km |
| Taper | Tempo 8km(T) → Interval 6km(I, 3×1000m) | 6, 5, 4 km |

`pool = usedRequired + optional.prefix(fillerCount)` where
`fillerCount = min(3, days.count - usedRequired.count)`.

### Worked table — sessions scheduled vs. rest days

| `availableDays.count` | Base (2 required) | Build/Peak (3 required) | Taper (2 required) |
| ---------------------- | ------------------ | ------------------------- | --------------------- |
| 1 (maintenance)         | 1 easy 5km          | 1 easy 5km                 | 1 easy 5km             |
| 2                       | 2 required, 0 rest extra | 2 of 3 required, 0 rest extra | 2 required, 0 rest extra |
| 3                       | 2 required + 1 filler | 3 required, 0 filler | 2 required + 1 filler |
| 4                       | 2 required + 2 fillers | 3 required + 1 filler | 2 required + 2 fillers |
| 5                       | 2 required + 3 fillers | 3 required + 2 fillers | 2 required + 3 fillers |
| 6                       | 2 required + 3 fillers (1 rest) | 3 required + 3 fillers | 2 required + 3 fillers (1 rest) |
| 7                       | 2 required + 3 fillers (2 rest) | 3 required + 3 fillers (1 rest) | 2 required + 3 fillers (2 rest) |

Running days never exceed `availableDays.count`, and at least one
session is always scheduled — covered by
`runningDaysWithinBudget` in the test suite.

---

## Placement algorithm (2+ days)

Once the `pool` of session specs is decided, `place(_:into:longRunDay:)`
assigns each spec to a weekday:

1. **Split into "hard" (`.long`, `.tempo`, `.interval`, `.repetition`)
   and "easy" specs.** Hard sessions get priority placement; easy
   fillers take whatever days remain.
2. **Choose hard-session days** via `chooseHardDays`: among all
   `count`-sized subsets of `availableDays`, prefer one where every
   pair of hard days is ≥2 apart on the **circular** 7-day week (so
   Sun=7 and Mon=1 count as adjacent). If no fully-spaced subset
   exists (e.g. only 2 consecutive days available), fall back to any
   subset. Ties are broken by preferring a set containing
   `longRunDay`, then Sunday, then Saturday.
3. **Place the long run** (if the phase has one) on
   `preferredLongRunDay`: the requested `longRunDay` if it's among the
   chosen hard days, else Sunday, else Saturday, else the latest
   chosen hard day.
4. **Place remaining hard specs** on the remaining chosen hard days, in
   spec order.
5. **Place easy fillers** on whatever `availableDays` remain, in spec
   order.

`hardSessionsAvoidAdjacencyWhenFeasible` brute-forces every multi-day
subset to confirm step 2 never settles for adjacent hard days when a
spaced arrangement was possible.

---

## Status

Implemented and tested (`TrainingPlanGenerator` +
`FlexibleTrainingDaysTests`, 27/27 passing). **Not yet wired up**:

- No UI for the runner to choose `availableDays` / `longRunDay`.
- No persisted column for these preferences (would live on `RaceGoal`
  or a settings table — TBD).
- No "regenerate current + future weeks" flow when the runner changes
  these preferences mid-plan.

See `ARCHITECTURE.md` §8 (Open questions and future work) for how this
fits alongside the rest of the roadmap.
