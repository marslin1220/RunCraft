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
        let template = sessionTemplate(for: week.phase, weekNumber: week.weekNumber)
        return template.enumerated().map { (idx, blueprint) in
            PlannedSession(
                weekId: week.id,
                dayOfWeek: blueprint.dayOfWeek,
                sessionType: blueprint.type,
                targetDistanceKm: blueprint.distanceKm,
                targetDurationMin: blueprint.durationMin,
                notes: blueprint.notes(zones)
            )
        }
    }

    private struct SessionBlueprint {
        let dayOfWeek: Int
        let type: SessionType
        let distanceKm: Double?
        let durationMin: Int?
        let notes: (PaceZones) -> String
    }

    private static func sessionTemplate(
        for phase: TrainingPhase,
        weekNumber: Int
    ) -> [SessionBlueprint] {
        switch phase {
        case .base:
            return [
                .init(dayOfWeek: 1, type: .easy,  distanceKm: 6,  durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 2, type: .rest,  distanceKm: nil, durationMin: nil, notes: { _ in "" }),
                .init(dayOfWeek: 3, type: .easy,  distanceKm: 8,  durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 4, type: .repetition, distanceKm: 5, durationMin: nil, notes: { z in "R strides \(z.repetition.formatted())" }),
                .init(dayOfWeek: 5, type: .rest,  distanceKm: nil, durationMin: nil, notes: { _ in "" }),
                .init(dayOfWeek: 6, type: .easy,  distanceKm: 10, durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 7, type: .long,  distanceKm: 14, durationMin: nil, notes: { z in "Long run E pace \(z.easy.formatted())" }),
            ]
        case .build:
            return [
                .init(dayOfWeek: 1, type: .easy,  distanceKm: 8,  durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 2, type: .tempo, distanceKm: 8,  durationMin: nil, notes: { z in "T pace \(z.threshold.formatted())" }),
                .init(dayOfWeek: 3, type: .easy,  distanceKm: 6,  durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 4, type: .rest,  distanceKm: nil, durationMin: nil, notes: { _ in "" }),
                .init(dayOfWeek: 5, type: .easy,  distanceKm: 8,  durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 6, type: .tempo, distanceKm: 10, durationMin: nil, notes: { z in "T pace \(z.threshold.formatted())" }),
                .init(dayOfWeek: 7, type: .long,  distanceKm: 18, durationMin: nil, notes: { z in "Long run E pace \(z.easy.formatted())" }),
            ]
        case .peak:
            return [
                .init(dayOfWeek: 1, type: .easy,     distanceKm: 8,  durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 2, type: .interval, distanceKm: 10, durationMin: nil, notes: { z in "5×1000m I pace \(z.interval.formatted())" }),
                .init(dayOfWeek: 3, type: .easy,     distanceKm: 6,  durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 4, type: .tempo,    distanceKm: 10, durationMin: nil, notes: { z in "T pace \(z.threshold.formatted())" }),
                .init(dayOfWeek: 5, type: .rest,     distanceKm: nil, durationMin: nil, notes: { _ in "" }),
                .init(dayOfWeek: 6, type: .easy,     distanceKm: 8,  durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 7, type: .long,     distanceKm: 24, durationMin: nil, notes: { z in "Long run E pace \(z.easy.formatted())" }),
            ]
        case .taper:
            return [
                .init(dayOfWeek: 1, type: .easy,     distanceKm: 6,  durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 2, type: .tempo,    distanceKm: 8,  durationMin: nil, notes: { z in "T pace \(z.threshold.formatted())" }),
                .init(dayOfWeek: 3, type: .easy,     distanceKm: 5,  durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 4, type: .rest,     distanceKm: nil, durationMin: nil, notes: { _ in "" }),
                .init(dayOfWeek: 5, type: .interval, distanceKm: 6,  durationMin: nil, notes: { z in "3×1000m I pace \(z.interval.formatted())" }),
                .init(dayOfWeek: 6, type: .easy,     distanceKm: 4,  durationMin: nil, notes: { z in "E pace \(z.easy.formatted())" }),
                .init(dayOfWeek: 7, type: .rest,     distanceKm: nil, durationMin: nil, notes: { _ in "Rest before race" }),
            ]
        }
    }
}
