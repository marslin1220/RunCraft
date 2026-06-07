import Foundation
import Testing
@testable import RunCraftModels

@Suite("TrainingWeek.current(in:at:)")
struct TrainingWeekCurrentTests {

    private let raceGoalId = UUID()
    /// Fixed reference Monday so test results don't depend on the wall clock.
    private let monday = ISO8601DateFormatter().date(from: "2026-01-05T00:00:00Z")!  // Mon
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    // MARK: - Inside / outside / boundary

    @Test("Date inside a week returns that week")
    func insideWeek() {
        let weeks = [
            makeWeek(weekNumber: 1, startsAt: monday),
            makeWeek(weekNumber: 2, startsAt: monday.addingTimeInterval(7 * 24 * 3600)),
        ]
        let wed = monday.addingTimeInterval(2 * 24 * 3600)
        let result = TrainingWeek.current(in: weeks, at: wed, calendar: calendar)
        #expect(result?.weekNumber == 1)
    }

    @Test("Date exactly at start of a week returns that week (inclusive lower bound)")
    func startOfWeek_isInclusive() {
        let weeks = [makeWeek(weekNumber: 5, startsAt: monday)]
        let result = TrainingWeek.current(in: weeks, at: monday, calendar: calendar)
        #expect(result?.weekNumber == 5)
    }

    @Test("Date exactly at start of the NEXT week returns the next week (exclusive upper bound)")
    func startOfNextWeek_belongsToNextWeek() {
        let weeks = [
            makeWeek(weekNumber: 1, startsAt: monday),
            makeWeek(weekNumber: 2, startsAt: monday.addingTimeInterval(7 * 24 * 3600)),
        ]
        let nextMonday = monday.addingTimeInterval(7 * 24 * 3600)
        let result = TrainingWeek.current(in: weeks, at: nextMonday, calendar: calendar)
        #expect(result?.weekNumber == 2)
    }

    @Test("Date before the first week returns nil")
    func beforeFirstWeek_isNil() {
        let weeks = [makeWeek(weekNumber: 1, startsAt: monday)]
        let yesterday = monday.addingTimeInterval(-24 * 3600)
        let result = TrainingWeek.current(in: weeks, at: yesterday, calendar: calendar)
        #expect(result == nil)
    }

    @Test("Date after the last week returns nil")
    func afterLastWeek_isNil() {
        let weeks = [makeWeek(weekNumber: 1, startsAt: monday)]
        let twoWeeksLater = monday.addingTimeInterval(14 * 24 * 3600)
        let result = TrainingWeek.current(in: weeks, at: twoWeeksLater, calendar: calendar)
        #expect(result == nil)
    }

    @Test("Empty array returns nil")
    func empty_isNil() {
        let result = TrainingWeek.current(in: [], at: monday, calendar: calendar)
        #expect(result == nil)
    }

    // MARK: - Helpers

    private func makeWeek(weekNumber: Int, startsAt: Date) -> TrainingWeek {
        TrainingWeek(
            id: UUID(),
            raceGoalId: raceGoalId,
            weekNumber: weekNumber,
            phase: .base,
            startDate: startsAt,
            targetWeeklyKm: 30
        )
    }
}
