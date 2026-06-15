import Foundation
import RunCraftModels
import SQLiteData
import Testing
import TrainingPlanFeature

@Suite("TrainingPlanRegeneration — regenerateFutureWeeks")
struct TrainingPlanRegenerationTests {

    private static let vdot = 40.0

    /// A race goal whose `targetDate` is `daysOut` days from `now`. With
    /// `daysOut == 56` (8 weeks), week 8's `startDate` lands exactly on
    /// `startOfDay(now)` — making it "current" — with weeks 1-7 in the
    /// past and weeks 9-16 in the future.
    private static func makeGoal(now: Date, daysOut: Int, availableDays: Set<Int>, longRunDay: Int? = nil) -> RaceGoal {
        var goal = RaceGoal(
            name: "Test Race",
            targetDate: Calendar.current.date(byAdding: .day, value: daysOut, to: now)!,
            distanceKm: 21.0,
            currentVDOT: vdot
        )
        goal.availableDays = availableDays
        goal.longRunDay = longRunDay
        return goal
    }

    private static func seed(goal: RaceGoal, db: Database) throws {
        try RaceGoal.upsert { goal }.execute(db)
        let (weeks, sessions) = TrainingPlanGenerator.generate(
            goal: goal, vdot: vdot, availableDays: goal.availableDays, longRunDay: goal.longRunDay
        )
        for week in weeks { try TrainingWeek.upsert { week }.execute(db) }
        for session in sessions { try PlannedSession.upsert { session }.execute(db) }
    }

    @Test("Current week's TrainingWeek/PlannedSession ids and CompletedWorkout link survive unchanged")
    func currentWeekUnchanged() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)
        let now = Date()

        let goal = Self.makeGoal(now: now, daysOut: 56, availableDays: Set(1...7))
        try await database.write { db in try Self.seed(goal: goal, db: db) }

        let (currentWeekId, linkedSessionId) = try await database.write { db -> (UUID, UUID) in
            let weeks = try TrainingWeek.where { $0.raceGoalId.eq(goal.id) }.fetchAll(db)
            let currentWeek = try #require(TrainingWeek.current(in: weeks, at: now))
            let sessions = try PlannedSession.where { $0.weekId.eq(currentWeek.id) }.fetchAll(db)
            let session = try #require(sessions.first)
            let completed = CompletedWorkout(
                plannedSessionId: session.id,
                actualDistanceKm: 5,
                actualDurationSec: 1_800,
                avgPaceSecPerKm: 360
            )
            try CompletedWorkout.upsert { completed }.execute(db)
            return (currentWeek.id, session.id)
        }

        var updatedGoal = goal
        updatedGoal.availableDays = [1, 2, 3, 4, 5]
        try await database.write { db in
            try RaceGoal.upsert { updatedGoal }.execute(db)
            try TrainingPlanRegeneration.regenerateFutureWeeks(goal: updatedGoal, vdot: Self.vdot, now: now, db: db)
        }

        let sessionsAfter = try await database.read { db in
            try PlannedSession.where { $0.weekId.eq(currentWeekId) }.fetchAll(db)
        }
        #expect(sessionsAfter.contains { $0.id == linkedSessionId })

        let completedAfter = try await database.read { db in try CompletedWorkout.all.fetchOne(db) }
        #expect(completedAfter?.plannedSessionId == linkedSessionId)
    }

    @Test("Future weeks reflect the new availableDays; past weeks are untouched")
    func futureWeeksRegenerated_pastWeeksUntouched() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)
        let now = Date()

        let goal = Self.makeGoal(now: now, daysOut: 56, availableDays: Set(1...7))
        try await database.write { db in try Self.seed(goal: goal, db: db) }

        let weeksBefore = try await database.read { db in
            try TrainingWeek.where { $0.raceGoalId.eq(goal.id) }.fetchAll(db)
        }
        let currentWeek = try #require(TrainingWeek.current(in: weeksBefore, at: now))
        let pastWeekIdsBefore = Set(weeksBefore.filter { $0.startDate < currentWeek.startDate }.map(\.id))

        var updatedGoal = goal
        updatedGoal.availableDays = [1, 2, 3, 4, 5] // weekdays only
        try await database.write { db in
            try RaceGoal.upsert { updatedGoal }.execute(db)
            try TrainingPlanRegeneration.regenerateFutureWeeks(goal: updatedGoal, vdot: Self.vdot, now: now, db: db)
        }

        let weeksAfter = try await database.read { db in
            try TrainingWeek.where { $0.raceGoalId.eq(goal.id) }.fetchAll(db)
        }
        #expect(weeksAfter.count == 16)

        let pastWeekIdsAfter = Set(weeksAfter.filter { $0.startDate < currentWeek.startDate }.map(\.id))
        #expect(pastWeekIdsAfter == pastWeekIdsBefore)

        let futureWeeks = weeksAfter.filter { $0.startDate > currentWeek.startDate }
        #expect(futureWeeks.count == 8) // weeks 9...16

        for week in futureWeeks {
            let sessions = try await database.read { db in
                try PlannedSession.where { $0.weekId.eq(week.id) }.fetchAll(db)
            }
            let saturday = sessions.first { $0.dayOfWeek == 6 }
            let sunday = sessions.first { $0.dayOfWeek == 7 }
            #expect(saturday?.sessionType == .rest)
            #expect(sunday?.sessionType == .rest)
        }
    }

    @Test("Placeholder goal is a no-op")
    func placeholderNoOp() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)
        let now = Date()

        var goal = RaceGoal(name: "Base Training", targetDate: now, distanceKm: 0, currentVDOT: Self.vdot, isPlaceholder: true)
        let (week, sessions) = TrainingPlanGenerator.rollingWeek(raceGoalId: goal.id, vdot: Self.vdot)
        try await database.write { db in
            try RaceGoal.upsert { goal }.execute(db)
            try TrainingWeek.upsert { week }.execute(db)
            for session in sessions { try PlannedSession.upsert { session }.execute(db) }
        }

        goal.availableDays = [1, 2, 3, 4, 5]
        try await database.write { db in
            try TrainingPlanRegeneration.regenerateFutureWeeks(goal: goal, vdot: Self.vdot, now: now, db: db)
        }

        let weeksAfter = try await database.read { db in
            try TrainingWeek.where { $0.raceGoalId.eq(goal.id) }.fetchAll(db)
        }
        #expect(weeksAfter.count == 1)
        #expect(weeksAfter.first?.id == week.id)
    }

    @Test("Race more than 16 weeks out: regenerates all 16 weeks")
    func noCurrentWeek_fullRegeneration() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)
        let now = Date()

        // 200 days ≈ 28.6 weeks out — every generated week's startDate is
        // still in the future, so none of them is "current".
        let goal = Self.makeGoal(now: now, daysOut: 200, availableDays: Set(1...7))
        try await database.write { db in try Self.seed(goal: goal, db: db) }

        let weeksBefore = try await database.read { db in
            try TrainingWeek.where { $0.raceGoalId.eq(goal.id) }.fetchAll(db)
        }
        #expect(TrainingWeek.current(in: weeksBefore, at: now) == nil)
        let weekIdsBefore = Set(weeksBefore.map(\.id))

        var updatedGoal = goal
        updatedGoal.availableDays = [1, 2, 3, 4, 5]
        try await database.write { db in
            try RaceGoal.upsert { updatedGoal }.execute(db)
            try TrainingPlanRegeneration.regenerateFutureWeeks(goal: updatedGoal, vdot: Self.vdot, now: now, db: db)
        }

        let weeksAfter = try await database.read { db in
            try TrainingWeek.where { $0.raceGoalId.eq(goal.id) }.fetchAll(db)
        }
        #expect(weeksAfter.count == 16)
        let weekIdsAfter = Set(weeksAfter.map(\.id))
        #expect(weekIdsAfter.isDisjoint(with: weekIdsBefore))

        for week in weeksAfter {
            let sessions = try await database.read { db in
                try PlannedSession.where { $0.weekId.eq(week.id) }.fetchAll(db)
            }
            let saturday = sessions.first { $0.dayOfWeek == 6 }
            let sunday = sessions.first { $0.dayOfWeek == 7 }
            #expect(saturday?.sessionType == .rest)
            #expect(sunday?.sessionType == .rest)
        }
    }
}
