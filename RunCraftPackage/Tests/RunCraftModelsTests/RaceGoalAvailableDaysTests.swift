import Dependencies
import Foundation
import SQLiteData
import Testing
@testable import RunCraftModels

@Suite("RaceGoal availableDays / longRunDay")
struct RaceGoalAvailableDaysTests {

    @Test("Defaults to all 7 days with no long-run preference")
    func defaults() {
        let goal = RaceGoal(name: "Test", targetDate: Date(), distanceKm: 10)
        #expect(goal.availableDays == Set(1...7))
        #expect(goal.longRunDay == nil)
    }

    @Test("Custom availableDays/longRunDay round-trip through availableDaysData")
    func roundTrip() {
        var goal = RaceGoal(name: "Test", targetDate: Date(), distanceKm: 10)
        goal.availableDays = [2, 4, 6, 7]
        goal.longRunDay = 7

        #expect(goal.availableDays == Set([2, 4, 6, 7]))
        #expect(goal.availableDaysData == "[2,4,6,7]")
        #expect(goal.longRunDay == 7)
    }

    @Test("Malformed or empty JSON falls back to all 7 days")
    func malformedFallsBack() {
        var goal = RaceGoal(name: "Test", targetDate: Date(), distanceKm: 10)

        goal.availableDaysData = "not json"
        #expect(goal.availableDays == Set(1...7))

        goal.availableDaysData = "[]"
        #expect(goal.availableDays == Set(1...7))
    }

    @Test("availableDaysData and longRunDay persist through insert/fetch")
    func persistsThroughDatabase() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)

        var goal = RaceGoal(name: "Test", targetDate: Date(), distanceKm: 10)
        goal.availableDays = [1, 3, 5]
        goal.longRunDay = 5
        let savedGoal = goal

        try await database.write { db in
            try RaceGoal.insert { savedGoal }.execute(db)
        }

        let fetched = try await database.read { db in
            try RaceGoal.where { $0.id.eq(savedGoal.id) }.fetchOne(db)
        }
        let saved = try #require(fetched)
        #expect(saved.availableDays == Set([1, 3, 5]))
        #expect(saved.longRunDay == 5)
    }
}
