import ComposableArchitecture
import Foundation
import RunCraftModels
import SQLiteData
import Testing
import TrainingPlanFeature

@MainActor
@Suite("AdjustTrainingDays — save / cancel")
struct AdjustTrainingDaysFeatureTests {

    private nonisolated static let vdot = 40.0

    /// A race goal 8 weeks (56 days) out, seeded with its full 16-week plan.
    private nonisolated static func seedGoal(now: Date, availableDays: Set<Int>, db: Database) throws -> RaceGoal {
        var goal = RaceGoal(
            name: "Test Race",
            targetDate: Calendar.current.date(byAdding: .day, value: 56, to: now)!,
            distanceKm: 21.0,
            currentVDOT: vdot
        )
        goal.availableDays = availableDays
        try RaceGoal.upsert { goal }.execute(db)

        let (weeks, sessions) = TrainingPlanGenerator.generate(
            goal: goal, vdot: vdot, availableDays: availableDays, longRunDay: nil
        )
        for week in weeks { try TrainingWeek.upsert { week }.execute(db) }
        for session in sessions { try PlannedSession.upsert { session }.execute(db) }
        return goal
    }

    @Test("saveTapped with changes persists new preferences and regenerates future weeks")
    func saveTapped_persistsAndRegenerates() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)
        let now = Date()

        let goal = try await database.write { db in try Self.seedGoal(now: now, availableDays: Set(1...7), db: db) }

        var state = AdjustTrainingDays.State(goal: goal)
        state.trainingDaysInput.availableDays = [1, 2, 3, 4, 5]
        #expect(state.hasChanged)

        let store = TestStore(initialState: state) {
            AdjustTrainingDays()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.date.now = now
        }

        await store.send(.saveTapped)
        await store.finish()

        let savedGoal = try await database.read { db in
            try RaceGoal.where { $0.id.eq(goal.id) }.fetchOne(db)
        }
        #expect(savedGoal?.availableDays == Set([1, 2, 3, 4, 5]))

        let weeks = try await database.read { db in
            try TrainingWeek.where { $0.raceGoalId.eq(goal.id) }.fetchAll(db)
        }
        let currentWeek = try #require(TrainingWeek.current(in: weeks, at: now))
        let futureWeeks = weeks.filter { $0.startDate > currentWeek.startDate }
        #expect(futureWeeks.count == 8)

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

    @Test("cancelTapped dismisses without writing")
    func cancelTapped_doesNotWrite() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)
        let now = Date()

        let goal = try await database.write { db in try Self.seedGoal(now: now, availableDays: Set(1...7), db: db) }

        var state = AdjustTrainingDays.State(goal: goal)
        state.trainingDaysInput.availableDays = [1, 2, 3, 4, 5]

        let store = TestStore(initialState: state) {
            AdjustTrainingDays()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.date.now = now
        }

        await store.send(.cancelTapped)
        await store.finish()

        let savedGoal = try await database.read { db in
            try RaceGoal.where { $0.id.eq(goal.id) }.fetchOne(db)
        }
        #expect(savedGoal?.availableDays == Set(1...7))
    }

    @Test("saveTapped with no changes dismisses without writing")
    func saveTapped_noChanges_doesNotWrite() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)
        let now = Date()

        let goal = try await database.write { db in try Self.seedGoal(now: now, availableDays: Set(1...7), db: db) }

        let state = AdjustTrainingDays.State(goal: goal)
        #expect(!state.hasChanged)

        let store = TestStore(initialState: state) {
            AdjustTrainingDays()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.date.now = now
        }

        await store.send(.saveTapped)
        await store.finish()

        let weeksAfter = try await database.read { db in
            try TrainingWeek.where { $0.raceGoalId.eq(goal.id) }.fetchAll(db)
        }
        #expect(weeksAfter.count == 16)
    }
}
