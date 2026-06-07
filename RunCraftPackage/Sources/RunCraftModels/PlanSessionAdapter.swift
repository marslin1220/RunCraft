import Foundation
import RunCraftModels

/// Converts a daily plan session (sessionType + target distance/time) into a
/// runnable `WorkoutTemplate` with sensible warm-up/work/cool-down structure.
///
/// Used by the Workshop "Plan" tab so plan sessions can be opened in the same
/// detail/editor flow as user-created workouts and built-in templates.
public enum PlanSessionAdapter {

    public static func makeTemplate(
        from session: PlannedSession,
        vdot: Double
    ) -> WorkoutTemplate {
        let name = displayName(for: session)
        let blocks = blocks(for: session, vdot: vdot)
        return WorkoutTemplate(
            id: session.id,            // reuse session id so we can map back
            name: name,
            blocks: blocks,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Naming

    private static func displayName(for session: PlannedSession) -> String {
        let kind = session.sessionType.displayName
        if let km = session.targetDistanceKm, km > 0 {
            return "\(kind) · \(km.formatted(.number.precision(.fractionLength(0...1)))) km"
        } else if let min = session.targetDurationMin, min > 0 {
            return "\(kind) · \(min) min"
        }
        return kind
    }

    // MARK: - Block layout per session type

    private static func blocks(for session: PlannedSession, vdot: Double) -> [WorkoutBlock] {
        switch session.sessionType {
        case .rest:
            return []

        case .easy, .long:
            return easyOrLong(distanceKm: session.targetDistanceKm, durationMin: session.targetDurationMin, vdot: vdot)

        case .tempo:
            return tempo(distanceKm: session.targetDistanceKm, durationMin: session.targetDurationMin, vdot: vdot)

        case .interval:
            return interval(totalKm: session.targetDistanceKm ?? 10, vdot: vdot)

        case .repetition:
            return repetition(vdot: vdot)
        }
    }

    private static func easyOrLong(distanceKm: Double?, durationMin: Int?, vdot: Double) -> [WorkoutBlock] {
        let goal: StepGoal = if let km = distanceKm, km > 0 {
            .distance(metres: km * 1_000)
        } else if let min = durationMin, min > 0 {
            .time(seconds: min * 60)
        } else {
            .time(seconds: 30 * 60)
        }
        return [
            .step(WorkoutStep(
                kind: .work,
                goal: goal,
                alert: .paceZone(.easy, vdot: vdot)
            )),
        ]
    }

    private static func tempo(distanceKm: Double?, durationMin: Int?, vdot: Double) -> [WorkoutBlock] {
        let tempoGoal: StepGoal = if let km = distanceKm, km > 0 {
            // First 10 min warm-up + tempo on remaining ~70% + cool-down
            .distance(metres: km * 1_000 * 0.7)
        } else if let min = durationMin, min > 0 {
            .time(seconds: max(min - 20, 20) * 60)
        } else {
            .time(seconds: 20 * 60)
        }
        return [
            .step(WorkoutStep(
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(.easy, vdot: vdot)
            )),
            .step(WorkoutStep(
                kind: .work,
                goal: tempoGoal,
                alert: .paceZone(.threshold, vdot: vdot)
            )),
            .step(WorkoutStep(
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(.easy, vdot: vdot)
            )),
        ]
    }

    private static func interval(totalKm: Double, vdot: Double) -> [WorkoutBlock] {
        // Build 5×1000m default; equation is "interval work ≈ 5km of distance budget"
        let reps = 5
        return [
            .step(WorkoutStep(
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(.easy, vdot: vdot)
            )),
            .repeatGroup(RepeatGroup(
                iterations: reps,
                steps: [
                    WorkoutStep(
                        kind: .work,
                        goal: .distance(metres: 1_000),
                        alert: .paceZone(.interval, vdot: vdot)
                    ),
                    WorkoutStep(
                        kind: .recovery,
                        goal: .time(seconds: 90),
                        alert: .paceZone(.easy, vdot: vdot)
                    ),
                ]
            )),
            .step(WorkoutStep(
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(.easy, vdot: vdot)
            )),
        ]
    }

    private static func repetition(vdot: Double) -> [WorkoutBlock] {
        return [
            .step(WorkoutStep(
                kind: .warmup,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(.easy, vdot: vdot)
            )),
            .repeatGroup(RepeatGroup(
                iterations: 8,
                steps: [
                    WorkoutStep(
                        kind: .work,
                        goal: .distance(metres: 200),
                        alert: .paceZone(.repetition, vdot: vdot)
                    ),
                    WorkoutStep(
                        kind: .recovery,
                        goal: .distance(metres: 200),
                        alert: .paceZone(.easy, vdot: vdot)
                    ),
                ]
            )),
            .step(WorkoutStep(
                kind: .cooldown,
                goal: .time(seconds: 10 * 60),
                alert: .paceZone(.easy, vdot: vdot)
            )),
        ]
    }
}
