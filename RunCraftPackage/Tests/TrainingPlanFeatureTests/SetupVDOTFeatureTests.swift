import ComposableArchitecture
import Foundation
import RunCraftModels
import SQLiteData
import Testing
import TrainingPlanFeature

@MainActor
@Suite("SetupVDOT — Save writes a placeholder goal + rolling week + sessions")
struct SetupVDOTFeatureTests {

    @Test("saveButtonTapped writes RaceGoal, TrainingWeek, and exactly 7 PlannedSessions")
    func saveButtonTapped_writesFullRollingWeek() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)

        let now = Date()

        var state = SetupVDOT.State()
        state.vdotInput.manualDistance = .fiveK
        state.vdotInput.manualMinutes = 25
        state.vdotInput.manualSeconds = 0
        #expect(state.vdotInput.effectiveVDOT != nil, "manual entry should produce a calculable VDOT")

        let store = TestStore(initialState: state) {
            SetupVDOT()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.date.now = now
        }

        await store.send(.saveButtonTapped)
        await store.finish()

        let goals = try await database.read { db in try RaceGoal.all.fetchAll(db) }
        #expect(goals.count == 1)
        let goal = try #require(goals.first)
        #expect(goal.isPlaceholder == true)
        #expect(goal.name == "Base Training")

        let weeks = try await database.read { db in
            try TrainingWeek.where { $0.raceGoalId.eq(goal.id) }.fetchAll(db)
        }
        #expect(weeks.count == 1)
        let week = try #require(weeks.first)
        #expect(week.weekNumber == 1)
        #expect(week.phase == .base)

        let sessions = try await database.read { db in
            try PlannedSession.where { $0.weekId.eq(week.id) }.fetchAll(db)
        }
        #expect(sessions.count == 7, "expected 7 sessions (5 runs + 2 rest days), got \(sessions.count)")

        let snapshots = try await database.read { db in try VDOTSnapshot.all.fetchAll(db) }
        #expect(snapshots.count == 1)
    }
}
