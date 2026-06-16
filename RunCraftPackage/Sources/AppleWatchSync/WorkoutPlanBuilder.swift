import Foundation
import RunCraftModels
#if canImport(WorkoutKit)
import HealthKit
import WorkoutKit

/// Pure conversion from `RunCraftModels.WorkoutTemplate` to WorkoutKit's
/// `WorkoutPlan`, ready to push to the Apple Watch Workout app.
public enum WorkoutPlanBuilder {

    /// Build a running `CustomWorkout` and wrap it in a `WorkoutPlan`.
    ///
    /// Layout rules:
    /// - First block, if it's a `.step(.warmup)`, becomes the `warmup` slot.
    /// - Last block, if it's a `.step(.cooldown)`, becomes the `cooldown` slot.
    /// - Everything in between becomes `IntervalBlock`s:
    ///     • a `.step` becomes a one-iteration block with a single step
    ///     • a `.repeatGroup` becomes a multi-iteration block with the inner steps
    public static func makePlan(name: String, blocks: [WorkoutBlock]) throws -> WorkoutPlan {
        var remaining = blocks
        var warmup: WorkoutKit.WorkoutStep? = nil
        var cooldown: WorkoutKit.WorkoutStep? = nil

        if case let .step(s) = remaining.first, s.kind == .warmup {
            warmup = convertStep(s)
            remaining.removeFirst()
        }
        if case let .step(s) = remaining.last, s.kind == .cooldown {
            cooldown = convertStep(s)
            remaining.removeLast()
        }

        let intervalBlocks: [IntervalBlock] = remaining.map { block in
            switch block {
            case let .step(step):
                return IntervalBlock(
                    steps: [convertIntervalStep(step)],
                    iterations: 1
                )
            case let .repeatGroup(group):
                return IntervalBlock(
                    steps: group.steps.map(convertIntervalStep),
                    iterations: group.iterations
                )
            }
        }

        let custom = CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: name,
            warmup: warmup,
            blocks: intervalBlocks,
            cooldown: cooldown
        )
        return WorkoutPlan(.custom(custom))
    }

    /// Convenience wrapper for the iOS template path — extracts `name` and
    /// `blocks` from a `WorkoutTemplate` and delegates to
    /// ``makePlan(name:blocks:)``.
    public static func makePlan(from template: WorkoutTemplate) throws -> WorkoutPlan {
        try makePlan(name: template.name, blocks: template.blocks)
    }

    // MARK: - Step conversion

    private static func convertStep(_ step: RunCraftModels.WorkoutStep) -> WorkoutKit.WorkoutStep {
        WorkoutKit.WorkoutStep(
            goal: convertGoal(step.goal),
            alert: convertAlert(step.alert)
        )
    }

    private static func convertIntervalStep(_ step: RunCraftModels.WorkoutStep) -> IntervalStep {
        let purpose: IntervalStep.Purpose = switch step.kind {
        case .work, .warmup, .cooldown: .work
        case .recovery:                 .recovery
        }
        return IntervalStep(
            purpose,
            step: convertStep(step)
        )
    }

    private static func convertGoal(_ goal: StepGoal) -> WorkoutGoal {
        switch goal {
        case .openEnded:
            return .open
        case .distance(let metres):
            return .distance(metres, .meters)
        case .time(let seconds):
            return .time(Double(seconds), .seconds)
        }
    }

    private static func convertAlert(_ alert: StepAlert?) -> (any WorkoutAlert)? {
        guard let alert else { return nil }
        switch alert {
        case let .paceRange(lo, hi):
            // sec/km → speed range (m/s); reciprocal so max speed corresponds to min pace.
            let lowSpeed  = 1_000.0 / Double(hi)
            let highSpeed = 1_000.0 / Double(lo)
            return SpeedRangeAlert.speed(
                lowSpeed...highSpeed,
                unit: .metersPerSecond,
                metric: .current
            )
        case let .heartRate(lo, hi):
            return HeartRateRangeAlert.heartRate(
                Double(lo)...Double(hi),
                unit: WorkoutAlertMetric.countPerMinute
            )
        }
    }
}
#endif
