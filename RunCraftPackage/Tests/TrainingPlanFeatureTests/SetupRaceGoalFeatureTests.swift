import ComposableArchitecture
import Foundation
import RunCraftModels
import SQLiteData
import Testing
import TrainingPlanFeature

@MainActor
@Suite("SetupRaceGoal — Save persists training-day preferences")
struct SetupRaceGoalFeatureTests {

    @Test("saveButtonTapped persists availableDays/longRunDay, and weekend sessions become rest")
    func saveButtonTapped_persistsTrainingDays() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)

        let now = Date()

        var state = SetupRaceGoal.State()
        state.goalName = "Test Race"
        state.vdotInput.manualDistance = .fiveK
        state.vdotInput.manualMinutes = 25
        state.vdotInput.manualSeconds = 0
        state.trainingDaysInput.availableDays = [1, 2, 3, 4, 5]
        state.trainingDaysInput.longRunDay = 5

        let store = TestStore(initialState: state) {
            SetupRaceGoal()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.date.now = now
        }

        await store.send(.saveButtonTapped)
        await store.finish()

        let goal = try await database.read { db in try RaceGoal.all.fetchOne(db) }
        let savedGoal = try #require(goal)
        #expect(savedGoal.availableDays == Set([1, 2, 3, 4, 5]))
        #expect(savedGoal.longRunDay == 5)

        let weeks = try await database.read { db in
            try TrainingWeek.where { $0.raceGoalId.eq(savedGoal.id) }.fetchAll(db)
        }
        #expect(weeks.count == 16)

        for week in weeks {
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
