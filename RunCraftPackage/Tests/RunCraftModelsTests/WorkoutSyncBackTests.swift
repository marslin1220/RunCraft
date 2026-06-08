import Foundation
import Testing
import VDOTEngine
@testable import RunCraftModels

@Suite("WorkoutSyncBack")
struct WorkoutSyncBackTests {

    private let raceGoalId = UUID()
    private let weekId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let sessionId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let fixedNewId = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
    private let monday = ISO8601DateFormatter().date(from: "2026-01-05T00:00:00Z")!
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    @Test("Workout inside a planned week+day links to that session")
    func matches_byWeekAndDay() {
        let week = makeWeek(startsAt: monday)
        let session = makeSession(dayOfWeek: 3, type: .easy, zone: .easy)
        let monday0830 = monday.addingTimeInterval(2 * 86_400 + 8 * 3600 + 30 * 60) // Wed 08:30
        let obs = WorkoutObservation(
            id: "hk-1",
            startDate: monday0830,
            duration: 30 * 60,
            distanceMeters: 5_000
        )

        let row = WorkoutSyncBack.makeCompletedWorkout(
            from: obs, weeks: [week], sessions: [session], currentVDOT: 40,
            newId: fixedNewId, calendar: calendar
        )

        #expect(row != nil)
        #expect(row?.plannedSessionId == session.id)
        #expect(row?.hkWorkoutId == "hk-1")
        #expect(row?.actualDistanceKm == 5.0)
        #expect(row?.actualDurationSec == 1800)
    }

    @Test("Workout with zero distance returns nil (won't insert)")
    func zeroDistance_returnsNil() {
        let obs = WorkoutObservation(
            id: "x", startDate: monday, duration: 100, distanceMeters: 0
        )
        let row = WorkoutSyncBack.makeCompletedWorkout(
            from: obs, weeks: [], sessions: [], currentVDOT: 40, calendar: calendar
        )
        #expect(row == nil)
    }

    @Test("Workout outside any tracked week still records but has no planned link")
    func unmatchedWeek_keepsRowButNoLink() {
        let lateDate = monday.addingTimeInterval(30 * 86_400)   // 30 days later, outside
        let obs = WorkoutObservation(
            id: "hk-2", startDate: lateDate, duration: 1800, distanceMeters: 5_000
        )
        let row = WorkoutSyncBack.makeCompletedWorkout(
            from: obs,
            weeks: [makeWeek(startsAt: monday)],   // only one week
            sessions: [],
            currentVDOT: 40,
            calendar: calendar
        )
        #expect(row != nil)
        #expect(row?.plannedSessionId == nil)
        #expect(row?.hkWorkoutId == "hk-2")
    }

    @Test("Pace achievement: faster than target → ratio < 1.0")
    func paceRatio_overperformance() {
        let week = makeWeek(startsAt: monday)
        // Tempo with .threshold zone
        let session = makeSession(dayOfWeek: 2, type: .tempo, zone: .threshold)
        let tueMorning = monday.addingTimeInterval(86_400 + 9 * 3600)
        // VDOT 40 threshold ≈ 5:22-5:23 /km → ~322 sec/km midpoint
        // 1 km in 290 sec = much faster → ratio ~0.9
        let obs = WorkoutObservation(
            id: "hk-3", startDate: tueMorning, duration: 290, distanceMeters: 1_000
        )

        let row = WorkoutSyncBack.makeCompletedWorkout(
            from: obs, weeks: [week], sessions: [session], currentVDOT: 40,
            calendar: calendar
        )

        #expect(row?.paceAchievementRatio != nil)
        #expect((row?.paceAchievementRatio ?? 1.0) < 0.95,
                "expected ratio < 0.95 (≥5% faster than target), got \(row?.paceAchievementRatio ?? -1)")
    }

    @Test("Pace achievement: no target zone → ratio defaults to 1.0")
    func paceRatio_noZone_isNeutral() {
        let week = makeWeek(startsAt: monday)
        let session = makeSession(dayOfWeek: 1, type: .easy, zone: nil)
        let monAm = monday.addingTimeInterval(9 * 3600)
        let obs = WorkoutObservation(
            id: "hk-4", startDate: monAm, duration: 1800, distanceMeters: 5_000
        )

        let row = WorkoutSyncBack.makeCompletedWorkout(
            from: obs, weeks: [week], sessions: [session], currentVDOT: 40,
            calendar: calendar
        )

        #expect(row?.paceAchievementRatio == 1.0)
    }

    // MARK: - Helpers

    private func makeWeek(startsAt: Date) -> TrainingWeek {
        TrainingWeek(
            id: weekId,
            raceGoalId: raceGoalId,
            weekNumber: 1,
            phase: .base,
            startDate: startsAt,
            targetWeeklyKm: 30
        )
    }

    private func makeSession(
        dayOfWeek: Int,
        type: SessionType,
        zone: PaceZoneName?
    ) -> PlannedSession {
        PlannedSession(
            id: sessionId,
            weekId: weekId,
            dayOfWeek: dayOfWeek,
            sessionType: type,
            targetDistanceKm: 5,
            targetDurationMin: nil,
            targetPaceZone: zone,
            notes: ""
        )
    }
}
