import Foundation
import RunCraftModels
import VDOTEngine

/// Pure function: given a race goal and VDOT, generate a 16-week periodized training schedule.
///
/// Phase structure (Jack Daniels):
///   Weeks 1–4:  Base  — 80% Easy, 20% Repetition strides
///   Weeks 5–8:  Build — introduce Tempo; weekly km +10% per week
///   Weeks 9–12: Peak  — Intervals + long run; highest mileage
///   Weeks 13–16: Taper — maintain intensity, reduce volume -20%/wk
public struct TrainingPlanGenerator {

    public static func generate(
        goal: RaceGoal,
        vdot: Double,
        availableDays: Set<Int> = Set(1...7),
        longRunDay: Int? = nil
    ) -> (weeks: [TrainingWeek], sessions: [PlannedSession]) {
        let zones = VDOTCalculator.paceZones(vdot: vdot)
        let today = Calendar.current.startOfDay(for: Date())
        let race = Calendar.current.startOfDay(for: goal.targetDate)
        let totalWeeks = 16

        var weeks: [TrainingWeek] = []
        var sessions: [PlannedSession] = []

        for weekIndex in 0..<totalWeeks {
            let reverseIndex = totalWeeks - 1 - weekIndex   // 15 = first week, 0 = taper
            let weekStartDate = Calendar.current.date(
                byAdding: .weekOfYear, value: -(reverseIndex), to: race
            ) ?? today

            let phase = Self.phase(for: weekIndex)
            let baseKm = baseWeeklyKm(for: goal.distanceKm)
            let targetKm = weeklyKm(for: weekIndex, base: baseKm, phase: phase)

            let week = TrainingWeek(
                raceGoalId: goal.id,
                weekNumber: weekIndex + 1,
                phase: phase,
                startDate: weekStartDate,
                targetWeeklyKm: targetKm
            )
            weeks.append(week)

            let weekSessions = Self.sessions(
                for: week, zones: zones, availableDays: availableDays, longRunDay: longRunDay
            )
            sessions.append(contentsOf: weekSessions)
        }

        return (weeks, sessions)
    }

    /// A single "Base" `TrainingWeek` + sessions anchored to the current
    /// calendar week — the rolling plan behind a placeholder `RaceGoal` (no
    /// race goal set, VDOT-only "Base Training" state).
    ///
    /// Also reused for a real race goal whose 16-week plan doesn't cover
    /// "today" (race more than 16 weeks out, or already past). In that case
    /// pass `weekNumber: 0` — a sentinel that keeps this filler week out of
    /// the periodized week-1...16 numbering so Full Schedule isn't confused
    /// by a duplicate "Week 1".
    public static func rollingWeek(
        raceGoalId: UUID, vdot: Double, weekNumber: Int = 1,
        availableDays: Set<Int> = Set(1...7), longRunDay: Int? = nil
    ) -> (week: TrainingWeek, sessions: [PlannedSession]) {
        let zones = VDOTCalculator.paceZones(vdot: vdot)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // Sun=1...Sat=7
        let daysSinceMonday = (weekday + 5) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today

        let week = TrainingWeek(
            raceGoalId: raceGoalId,
            weekNumber: weekNumber,
            phase: .base,
            startDate: weekStart,
            targetWeeklyKm: baseWeeklyKm(for: 0)
        )
        return (week, Self.sessions(
            for: week, zones: zones, availableDays: availableDays, longRunDay: longRunDay
        ))
    }

    // MARK: - Phase

    private static func phase(for weekIndex: Int) -> TrainingPhase {
        switch weekIndex {
        case 0..<4:  .base
        case 4..<8:  .build
        case 8..<12: .peak
        default:     .taper
        }
    }

    // MARK: - Weekly volume

    private static func baseWeeklyKm(for raceDistanceKm: Double) -> Double {
        switch raceDistanceKm {
        case ..<10:  25
        case ..<22:  35
        case ..<30:  40
        default:     50
        }
    }

    private static func weeklyKm(for weekIndex: Int, base: Double, phase: TrainingPhase) -> Double {
        let buildMultiplier: Double
        switch phase {
        case .base:  buildMultiplier = 1.0 + Double(weekIndex % 4) * 0.08
        case .build: buildMultiplier = 1.32 + Double(weekIndex % 4) * 0.10
        case .peak:  buildMultiplier = 1.72 + Double(weekIndex % 4) * 0.05
        case .taper: buildMultiplier = 1.82 - Double(weekIndex % 4) * 0.20
        }
        return (base * max(buildMultiplier, 0.5)).rounded()
    }

    // MARK: - Session layout

    /// A single non-rest session candidate. Pace text is never baked in:
    /// `paceZone` carries the intent, and the actual sec/km is derived from
    /// the current VDOT at render time so the schedule stays honest as the
    /// runner adapts. `notes` carries structural hints only (e.g. "5×1000m").
    private struct SessionSpec {
        let type: SessionType
        let distanceKm: Double?
        let paceZone: PaceZoneName?
        let notes: String

        init(
            type: SessionType,
            distanceKm: Double? = nil,
            paceZone: PaceZoneName? = nil,
            notes: String = ""
        ) {
            self.type = type
            self.distanceKm = distanceKm
            self.paceZone = paceZone
            self.notes = notes
        }
    }

    /// Session types that should not land on consecutive days when avoidable.
    private static let hardSessionTypes: Set<SessionType> = [.long, .tempo, .interval, .repetition]

    /// Priority-ordered "must schedule" sessions for a phase. The long run
    /// (if any) is always first. When `availableDays` is smaller than this
    /// list, the lowest-priority (trailing) entries are dropped first.
    private static func requiredSessionSpecs(for phase: TrainingPhase) -> [SessionSpec] {
        switch phase {
        case .base:
            return [
                .init(type: .long,       distanceKm: 14, paceZone: .easy),
                .init(type: .repetition, distanceKm: 5,  paceZone: .repetition, notes: "R strides"),
            ]
        case .build:
            return [
                .init(type: .long,  distanceKm: 18, paceZone: .easy),
                .init(type: .tempo, distanceKm: 10, paceZone: .threshold),
                .init(type: .tempo, distanceKm: 8,  paceZone: .threshold),
            ]
        case .peak:
            return [
                .init(type: .long,     distanceKm: 24, paceZone: .easy),
                .init(type: .interval, distanceKm: 10, paceZone: .interval, notes: "5×1000m"),
                .init(type: .tempo,    distanceKm: 10, paceZone: .threshold),
            ]
        case .taper:
            return [
                .init(type: .tempo,    distanceKm: 8, paceZone: .threshold),
                .init(type: .interval, distanceKm: 6, paceZone: .interval, notes: "3×1000m"),
            ]
        }
    }

    /// Easy-run fillers used to round out the week once the required
    /// sessions are placed (up to 3 of them).
    private static func optionalFillerSpecs(for phase: TrainingPhase) -> [SessionSpec] {
        let distances: [Double]
        switch phase {
        case .base:  distances = [6, 8, 10]
        case .build: distances = [8, 8, 8]
        case .peak:  distances = [8, 8, 6]
        case .taper: distances = [6, 5, 4]
        }
        return distances.map { .init(type: .easy, distanceKm: $0, paceZone: .easy) }
    }

    private static func sessions(
        for week: TrainingWeek,
        zones: PaceZones,
        availableDays: Set<Int> = Set(1...7),
        longRunDay: Int? = nil
    ) -> [PlannedSession] {
        let days = availableDays.sorted()

        let pool: [SessionSpec]
        let effectiveLongRunDay: Int?
        if days.count <= 1 {
            // Maintenance mode: a single easy run, ignoring phase/periodization.
            pool = [.init(type: .easy, distanceKm: 5, paceZone: .easy)]
            effectiveLongRunDay = nil
        } else {
            let required = requiredSessionSpecs(for: week.phase)
            let optional = optionalFillerSpecs(for: week.phase)
            let usedRequired = Array(required.prefix(min(required.count, days.count)))
            let fillerCount = min(3, days.count - usedRequired.count)
            pool = usedRequired + Array(optional.prefix(fillerCount))
            effectiveLongRunDay = longRunDay
        }

        let placements = place(pool, into: days, longRunDay: effectiveLongRunDay)

        return (1...7).map { day in
            if let spec = placements[day] {
                return PlannedSession(
                    weekId: week.id,
                    dayOfWeek: day,
                    sessionType: spec.type,
                    targetDistanceKm: spec.distanceKm,
                    targetPaceZone: spec.paceZone,
                    notes: spec.notes
                )
            } else {
                return PlannedSession(weekId: week.id, dayOfWeek: day, sessionType: .rest)
            }
        }
    }

    /// Assigns each spec in `pool` to a day in `availableDays`, preferring to
    /// keep `hardSessionTypes` non-adjacent (on the 7-day cycle, where day 7
    /// and day 1 are neighbors) and to put the long run on `longRunDay` —
    /// defaulting to a weekend day when unspecified or unavailable.
    private static func place(
        _ pool: [SessionSpec], into days: [Int], longRunDay: Int?
    ) -> [Int: SessionSpec] {
        let hardSpecs = pool.filter { hardSessionTypes.contains($0.type) }
        let easySpecs = pool.filter { !hardSessionTypes.contains($0.type) }
        let hasLong = hardSpecs.contains { $0.type == .long }

        let hardDays = chooseHardDays(
            count: hardSpecs.count, from: days, preferring: hasLong ? longRunDay : nil
        )

        var placements: [Int: SessionSpec] = [:]
        var remainingHardDays = hardDays
        var remainingHardSpecs = hardSpecs

        if hasLong, let longIndex = remainingHardSpecs.firstIndex(where: { $0.type == .long }) {
            let longDay = preferredLongRunDay(among: hardDays, requested: longRunDay)
            placements[longDay] = remainingHardSpecs.remove(at: longIndex)
            remainingHardDays.removeAll { $0 == longDay }
        }

        for (day, spec) in zip(remainingHardDays, remainingHardSpecs) {
            placements[day] = spec
        }

        let easyDays = days.filter { placements[$0] == nil }
        let chosenEasyDays = spreadEasyDays(
            count: easySpecs.count,
            from: easyDays,
            occupied: Set(placements.keys)
        )
        for (day, spec) in zip(chosenEasyDays, easySpecs) {
            placements[day] = spec
        }

        return placements
    }

    /// Picks `count` days from `availableDays` for the "hard" sessions,
    /// preferring a fully circularly-spaced set (no two hard days adjacent,
    /// wrapping Sun→Mon) when one exists, then a set containing
    /// `preferredDay`, then one containing Sunday or Saturday.
    private static func chooseHardDays(
        count: Int, from availableDays: [Int], preferring preferredDay: Int?
    ) -> [Int] {
        guard count > 0 else { return [] }
        guard count < availableDays.count else { return availableDays }

        let candidates = combinations(of: availableDays, choose: count)
        let spaced = candidates.filter(isFullySpaced)
        let pool = spaced.isEmpty ? candidates : spaced

        return pool.min { lhs, rhs in
            rank(lhs, preferredDay: preferredDay).lexicographicallyPrecedes(rank(rhs, preferredDay: preferredDay))
        } ?? availableDays
    }

    /// Lower is "better": contains `preferredDay`, then contains Sunday,
    /// then contains Saturday, then lexicographically-smallest day list.
    private static func rank(_ days: [Int], preferredDay: Int?) -> [Int] {
        [
            preferredDay.map { days.contains($0) ? 0 : 1 } ?? 0,
            days.contains(7) ? 0 : 1,
            days.contains(6) ? 0 : 1,
        ] + days
    }

    /// Where the long run lands within `hardDays`: `requested` if available,
    /// else Sunday, else Saturday, else the latest available hard day.
    private static func preferredLongRunDay(among hardDays: [Int], requested: Int?) -> Int {
        if let requested, hardDays.contains(requested) { return requested }
        if hardDays.contains(7) { return 7 }
        if hardDays.contains(6) { return 6 }
        return hardDays.max() ?? 7
    }

    /// Picks `count` days from `candidates` for easy-run sessions.
    ///
    /// Evaluates every combination and picks the one that minimises the
    /// maximum linear consecutive training-day run (days 1–7) when the
    /// chosen days are merged with the already-placed hard-session days.
    /// Ties are broken by lexicographic order (smallest day numbers first).
    ///
    /// - Complexity: O(C(candidates, count)) — at most C(6,3)=20 combos.
    private static func spreadEasyDays(count: Int, from candidates: [Int], occupied: Set<Int>) -> [Int] {
        guard count > 0 else { return [] }
        guard count < candidates.count else { return candidates }
        let combos = combinations(of: candidates, choose: count)
        return combos.min { lhs, rhs in
            let ls = maxLinearConsecutiveRun(occupied.union(lhs))
            let rs = maxLinearConsecutiveRun(occupied.union(rhs))
            return ls != rs ? ls < rs : lhs.lexicographicallyPrecedes(rhs)
        } ?? Array(candidates.prefix(count))
    }

    /// Maximum run of consecutive integers (1…7) that appear in `days`.
    private static func maxLinearConsecutiveRun(_ days: Set<Int>) -> Int {
        var maxRun = 0, current = 0
        for d in 1...7 {
            if days.contains(d) { current += 1; maxRun = max(maxRun, current) }
            else { current = 0 }
        }
        return maxRun
    }

    /// All `choose`-sized subsets of `array`, preserving ascending order.
    private static func combinations(of array: [Int], choose: Int) -> [[Int]] {
        guard choose > 0 else { return [[]] }
        guard choose <= array.count else { return [] }
        guard choose < array.count else { return [array] }

        var result: [[Int]] = []
        for i in 0..<array.count {
            let rest = Array(array[(i + 1)...])
            guard rest.count >= choose - 1 else { break }
            for combo in combinations(of: rest, choose: choose - 1) {
                result.append([array[i]] + combo)
            }
        }
        return result
    }

    /// True if every pair of days is at least 2 days apart on the 7-day
    /// cycle (so Sun=7 and Mon=1 count as adjacent).
    private static func isFullySpaced(_ days: [Int]) -> Bool {
        for i in 0..<days.count {
            for j in (i + 1)..<days.count where circularDistance(days[i], days[j]) < 2 {
                return false
            }
        }
        return true
    }

    private static func circularDistance(_ a: Int, _ b: Int) -> Int {
        let diff = abs(a - b)
        return min(diff, 7 - diff)
    }
}
