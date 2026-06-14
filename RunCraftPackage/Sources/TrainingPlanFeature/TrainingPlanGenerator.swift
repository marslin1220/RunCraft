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
        vdot: Double
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

            let weekSessions = Self.sessions(for: week, zones: zones)
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
        raceGoalId: UUID, vdot: Double, weekNumber: Int = 1
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
        return (week, Self.sessions(for: week, zones: zones))
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
        case .taper: buildMultiplier = 1.92 - Double(weekIndex % 4) * 0.20
        }
        return (base * max(buildMultiplier, 0.5)).rounded()
    }

    // MARK: - Session layout

    private static func sessions(
        for week: TrainingWeek,
        zones: PaceZones
    ) -> [PlannedSession] {
        sessionTemplate(for: week.phase, weekNumber: week.weekNumber).map { blueprint in
            PlannedSession(
                weekId: week.id,
                dayOfWeek: blueprint.dayOfWeek,
                sessionType: blueprint.type,
                targetDistanceKm: blueprint.distanceKm,
                targetDurationMin: blueprint.durationMin,
                targetPaceZone: blueprint.paceZone,
                notes: blueprint.notes
            )
        }
    }

    private struct SessionBlueprint {
        let dayOfWeek: Int
        let type: SessionType
        let distanceKm: Double?
        let durationMin: Int?
        let paceZone: PaceZoneName?
        let notes: String

        init(
            dayOfWeek: Int,
            type: SessionType,
            distanceKm: Double? = nil,
            durationMin: Int? = nil,
            paceZone: PaceZoneName? = nil,
            notes: String = ""
        ) {
            self.dayOfWeek = dayOfWeek
            self.type = type
            self.distanceKm = distanceKm
            self.durationMin = durationMin
            self.paceZone = paceZone
            self.notes = notes
        }
    }

    private static func sessionTemplate(
        for phase: TrainingPhase,
        weekNumber: Int
    ) -> [SessionBlueprint] {
        // Per-blueprint: pace text never baked. `paceZone` carries the
        // intent; the actual sec/km is derived from the current VDOT at
        // render time so the schedule stays honest as the runner adapts.
        // `notes` carries structural hints only (e.g. "5×1000m").
        switch phase {
        case .base:
            return [
                .init(dayOfWeek: 1, type: .easy,       distanceKm: 6,  paceZone: .easy),
                .init(dayOfWeek: 2, type: .rest),
                .init(dayOfWeek: 3, type: .easy,       distanceKm: 8,  paceZone: .easy),
                .init(dayOfWeek: 4, type: .repetition, distanceKm: 5,  paceZone: .repetition, notes: "R strides"),
                .init(dayOfWeek: 5, type: .rest),
                .init(dayOfWeek: 6, type: .easy,       distanceKm: 10, paceZone: .easy),
                .init(dayOfWeek: 7, type: .long,       distanceKm: 14, paceZone: .easy),
            ]
        case .build:
            return [
                .init(dayOfWeek: 1, type: .easy,  distanceKm: 8,  paceZone: .easy),
                .init(dayOfWeek: 2, type: .tempo, distanceKm: 8,  paceZone: .threshold),
                .init(dayOfWeek: 3, type: .easy,  distanceKm: 6,  paceZone: .easy),
                .init(dayOfWeek: 4, type: .rest),
                .init(dayOfWeek: 5, type: .easy,  distanceKm: 8,  paceZone: .easy),
                .init(dayOfWeek: 6, type: .tempo, distanceKm: 10, paceZone: .threshold),
                .init(dayOfWeek: 7, type: .long,  distanceKm: 18, paceZone: .easy),
            ]
        case .peak:
            return [
                .init(dayOfWeek: 1, type: .easy,     distanceKm: 8,  paceZone: .easy),
                .init(dayOfWeek: 2, type: .interval, distanceKm: 10, paceZone: .interval,  notes: "5×1000m"),
                .init(dayOfWeek: 3, type: .easy,     distanceKm: 6,  paceZone: .easy),
                .init(dayOfWeek: 4, type: .tempo,    distanceKm: 10, paceZone: .threshold),
                .init(dayOfWeek: 5, type: .rest),
                .init(dayOfWeek: 6, type: .easy,     distanceKm: 8,  paceZone: .easy),
                .init(dayOfWeek: 7, type: .long,     distanceKm: 24, paceZone: .easy),
            ]
        case .taper:
            return [
                .init(dayOfWeek: 1, type: .easy,     distanceKm: 6, paceZone: .easy),
                .init(dayOfWeek: 2, type: .tempo,    distanceKm: 8, paceZone: .threshold),
                .init(dayOfWeek: 3, type: .easy,     distanceKm: 5, paceZone: .easy),
                .init(dayOfWeek: 4, type: .rest),
                .init(dayOfWeek: 5, type: .interval, distanceKm: 6, paceZone: .interval, notes: "3×1000m"),
                .init(dayOfWeek: 6, type: .easy,     distanceKm: 4, paceZone: .easy),
                .init(dayOfWeek: 7, type: .rest,     notes: "Rest before race"),
            ]
        }
    }
}
