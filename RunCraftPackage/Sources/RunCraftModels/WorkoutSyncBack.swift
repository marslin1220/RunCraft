import Foundation
import VDOTEngine

/// Pure mapping from "an HKWorkout I saw on the watch" to "a row in
/// `completedWorkouts` linked to the planned session it most likely
/// fulfilled". Lives next to `PlanSessionAdapter` — same shape, opposite
/// direction.
public enum WorkoutSyncBack {

    /// Decide which (if any) `PlannedSession` a workout fulfilled and
    /// build the `CompletedWorkout` row. Returns nil for a workout that
    /// should be skipped (e.g. zero distance).
    public static func makeCompletedWorkout(
        from workout: WorkoutObservation,
        weeks: [TrainingWeek],
        sessions: [PlannedSession],
        currentVDOT: Double,
        newId: UUID = UUID(),
        calendar: Calendar = .current
    ) -> CompletedWorkout? {
        guard workout.distanceMeters > 0, workout.duration > 0 else { return nil }
        let actualDistanceKm = workout.distanceMeters / 1_000
        let avgPaceSecPerKm  = workout.duration / actualDistanceKm

        // 1. Which week contained the workout date?
        let week = TrainingWeek.current(in: weeks, at: workout.startDate, calendar: calendar)

        // 2. Within that week, find the session with matching day-of-week.
        let session: PlannedSession? = week.flatMap { week in
            let weekday = calendar.component(.weekday, from: workout.startDate)
            let dayOfWeek = weekday == 1 ? 7 : weekday - 1
            return sessions.first { $0.weekId == week.id && $0.dayOfWeek == dayOfWeek }
        }

        // 3. Compute pace achievement vs the matched session's target zone.
        //    Ratio < 1 = faster than target (overperformance);
        //    Ratio > 1 = slower than target.
        let ratio: Double = {
            guard let session,
                  let zone = session.targetPaceZone,
                  currentVDOT > 0
            else { return 1.0 }
            let range = VDOTCalculator.paceRange(for: zone, vdot: currentVDOT)
            let midSecPerKm = (range.lower + range.upper) / 2
            return avgPaceSecPerKm / midSecPerKm
        }()

        return CompletedWorkout(
            id: newId,
            plannedSessionId: session?.id,
            hkWorkoutId: workout.id,
            completedAt: workout.startDate,
            actualDistanceKm: actualDistanceKm,
            actualDurationSec: workout.duration,
            avgPaceSecPerKm: avgPaceSecPerKm,
            paceAchievementRatio: ratio
        )
    }
}

/// HealthKit-agnostic projection of a single workout. Mirrors
/// `HealthKitClient.HKWorkoutSummary` — duplicated here so RunCraftModels
/// doesn't have to link HealthKitClient.
public struct WorkoutObservation: Sendable, Equatable {
    public let id: String
    public let startDate: Date
    public let duration: TimeInterval
    public let distanceMeters: Double

    public init(id: String, startDate: Date, duration: TimeInterval, distanceMeters: Double) {
        self.id = id
        self.startDate = startDate
        self.duration = duration
        self.distanceMeters = distanceMeters
    }
}
