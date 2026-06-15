import Foundation
import RunCraftModels
import SQLiteData

/// Re-places sessions for weeks that haven't started yet after a runner
/// changes `availableDays`/`longRunDay` mid-plan.
public enum TrainingPlanRegeneration {

    /// Applies `goal`'s (already-persisted) `availableDays`/`longRunDay` to
    /// every week that hasn't started yet. The current week (and all past
    /// weeks) are left untouched — this preserves any `CompletedWorkout`
    /// links into this week's `PlannedSession` rows (see
    /// `WorkoutSyncBack.makeCompletedWorkout`, which sets
    /// `plannedSessionId` once at sync-back time; that FK is
    /// `ON DELETE SET NULL`, so recreating this week's sessions would
    /// silently un-complete them). Call inside `database.write`.
    public static func regenerateFutureWeeks(goal: RaceGoal, vdot: Double, now: Date, db: Database) throws {
        guard !goal.isPlaceholder else {
            // State B has one rolling week == "current"; nothing future to
            // regenerate. New prefs apply next time
            // refreshRollingWeekIfNeeded re-anchors the rolling week.
            return
        }

        let allWeeks = try TrainingWeek.where { $0.raceGoalId.eq(goal.id) }.fetchAll(db)
        let (generatedWeeks, generatedSessions) = TrainingPlanGenerator.generate(
            goal: goal, vdot: vdot, availableDays: goal.availableDays, longRunDay: goal.longRunDay
        )

        guard let currentWeek = TrainingWeek.current(in: allWeeks, at: now) else {
            // No "current" week (race >16 weeks out, or already past) —
            // replace everything, same as the edit-goal path.
            try TrainingWeek.where { $0.raceGoalId.eq(goal.id) }.delete().execute(db)
            for week in generatedWeeks { try TrainingWeek.upsert { week }.execute(db) }
            for session in generatedSessions { try PlannedSession.upsert { session }.execute(db) }
            return
        }

        let futureWeeks = allWeeks.filter { $0.startDate > currentWeek.startDate }
        for week in futureWeeks {
            try TrainingWeek.where { $0.id.eq(week.id) }.delete().execute(db)
        }

        let regenWeeks = generatedWeeks.filter { $0.startDate > currentWeek.startDate }
        let regenWeekIds = Set(regenWeeks.map(\.id))
        let regenSessions = generatedSessions.filter { regenWeekIds.contains($0.weekId) }

        for week in regenWeeks { try TrainingWeek.upsert { week }.execute(db) }
        for session in regenSessions { try PlannedSession.upsert { session }.execute(db) }
    }
}
