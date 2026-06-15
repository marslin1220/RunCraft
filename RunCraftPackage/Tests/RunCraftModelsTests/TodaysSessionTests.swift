import Dependencies
import Foundation
import SQLiteData
import Testing
@testable import RunCraftModels

@Suite("TodaysSession")
struct TodaysSessionTests {

    // Monday, 2026-01-05 00:00 UTC → PlannedSession.dayOfWeek == 1 (Mon)
    private let monday = ISO8601DateFormatter().date(from: "2026-01-05T00:00:00Z")!
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    @Test("Returns today's session paired with the latest goal's VDOT")
    func returnsTodaysSessionAndVDOT() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)

        let goal = RaceGoal(name: "Test", targetDate: monday, distanceKm: 10, currentVDOT: 45)
        let week = TrainingWeek(raceGoalId: goal.id, weekNumber: 1, phase: .base, startDate: monday, targetWeeklyKm: 40)
        let session = PlannedSession(weekId: week.id, dayOfWeek: 1, sessionType: .tempo, targetDistanceKm: 8, targetPaceZone: .threshold)

        try await database.write { db in
            try RaceGoal.insert { goal }.execute(db)
            try TrainingWeek.insert { week }.execute(db)
            try PlannedSession.insert { session }.execute(db)
        }

        let today = try await database.read { db in
            try TodaysSession.current(in: db, at: monday, calendar: calendar)
        }

        let result = try #require(today)
        #expect(result.session.id == session.id)
        #expect(result.session.sessionType == .tempo)
        #expect(result.vdot == 45)
    }

    @Test("Returns nil when no training week covers the date")
    func returnsNilWithNoCurrentWeek() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)

        let goal = RaceGoal(name: "Test", targetDate: monday, distanceKm: 10, currentVDOT: 45)
        try await database.write { db in
            try RaceGoal.insert { goal }.execute(db)
        }

        let today = try await database.read { db in
            try TodaysSession.current(in: db, at: monday, calendar: calendar)
        }
        #expect(today == nil)
    }

    @Test("Returns nil when today's day-of-week has no planned session")
    func returnsNilWithNoSessionForToday() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)

        let goal = RaceGoal(name: "Test", targetDate: monday, distanceKm: 10, currentVDOT: 45)
        let week = TrainingWeek(raceGoalId: goal.id, weekNumber: 1, phase: .base, startDate: monday, targetWeeklyKm: 40)
        // Only Tuesday (dayOfWeek 2) has a session — Monday (dayOfWeek 1) does not.
        let tuesdaySession = PlannedSession(weekId: week.id, dayOfWeek: 2, sessionType: .easy, targetDistanceKm: 5)

        try await database.write { db in
            try RaceGoal.insert { goal }.execute(db)
            try TrainingWeek.insert { week }.execute(db)
            try PlannedSession.insert { tuesdaySession }.execute(db)
        }

        let today = try await database.read { db in
            try TodaysSession.current(in: db, at: monday, calendar: calendar)
        }
        #expect(today == nil)
    }

    @Test("Uses the most recently created RaceGoal's VDOT, regardless of which goal owns the current week")
    func usesLatestGoalVDOT() async throws {
        let database = try DatabaseQueue()
        try DependencyValues.migrate(database)

        let earlierGoal = RaceGoal(name: "Older", targetDate: monday, distanceKm: 10, currentVDOT: 40, createdAt: monday)
        let laterGoal = RaceGoal(name: "Newer", targetDate: monday, distanceKm: 10, currentVDOT: 55, createdAt: monday.addingTimeInterval(60))
        let week = TrainingWeek(raceGoalId: earlierGoal.id, weekNumber: 1, phase: .base, startDate: monday, targetWeeklyKm: 40)
        let session = PlannedSession(weekId: week.id, dayOfWeek: 1, sessionType: .easy, targetDistanceKm: 6)

        try await database.write { db in
            try RaceGoal.insert { earlierGoal }.execute(db)
            try RaceGoal.insert { laterGoal }.execute(db)
            try TrainingWeek.insert { week }.execute(db)
            try PlannedSession.insert { session }.execute(db)
        }

        let today = try await database.read { db in
            try TodaysSession.current(in: db, at: monday, calendar: calendar)
        }

        let result = try #require(today)
        #expect(result.vdot == 55)
    }
}
