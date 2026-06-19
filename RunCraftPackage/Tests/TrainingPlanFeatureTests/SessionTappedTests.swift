import ComposableArchitecture
import Foundation
import RunCraftModels
import Testing
@testable import TrainingPlanFeature
@testable import WorkshopFeature

// MARK: - Helpers

/// June 19 2026 12:00:00 UTC — a confirmed Friday, noon UTC so weekday
/// is unambiguous across all timezones from UTC-11 through UTC+11.
private let friday2026: Date = {
    var comps = DateComponents()
    comps.timeZone = TimeZone(identifier: "UTC")
    comps.year = 2026; comps.month = 6; comps.day = 19
    comps.hour = 12; comps.minute = 0; comps.second = 0
    return Calendar(identifier: .gregorian).date(from: comps)!
}()

/// June 18 2026 12:00:00 UTC — Thursday (day before Friday above).
private let thursday2026: Date = {
    var comps = DateComponents()
    comps.timeZone = TimeZone(identifier: "UTC")
    comps.year = 2026; comps.month = 6; comps.day = 18
    comps.hour = 12; comps.minute = 0; comps.second = 0
    return Calendar(identifier: .gregorian).date(from: comps)!
}()

private func fridaySession(weekId: UUID = UUID()) -> PlannedSession {
    PlannedSession(weekId: weekId, dayOfWeek: 5, sessionType: .easy, targetDistanceKm: 8, targetPaceZone: .easy)
}

private func wednesdaySession(weekId: UUID = UUID()) -> PlannedSession {
    PlannedSession(weekId: weekId, dayOfWeek: 3, sessionType: .tempo, targetDistanceKm: 10, targetPaceZone: .threshold)
}

// MARK: - WorkoutEditor.State.canStartOnWatch

@Suite("WorkoutEditor.State — canStartOnWatch")
struct CanStartOnWatchTests {

    @Test("plan session today with Watch available → can start")
    func planSessionToday_watchAvailable() {
        var state = WorkoutEditor.State(
            loading: .init(name: "Easy Run", blocks: []),
            asCopy: true, source: .planSession, isTodaySession: true
        )
        state.watchAvailable = true
        #expect(state.canStartOnWatch == true)
    }

    @Test("plan session NOT today → cannot start, regardless of Watch")
    func planSessionNotToday() {
        var state = WorkoutEditor.State(
            loading: .init(name: "Easy Run", blocks: []),
            asCopy: true, source: .planSession, isTodaySession: false
        )
        state.watchAvailable = true
        #expect(state.canStartOnWatch == false)
    }

    @Test("plan session today but Watch not available → cannot start")
    func planSessionToday_noWatch() {
        var state = WorkoutEditor.State(
            loading: .init(name: "Easy Run", blocks: []),
            asCopy: true, source: .planSession, isTodaySession: true
        )
        state.watchAvailable = false
        #expect(state.canStartOnWatch == false)
    }

    @Test("template source always can start (not plan-session restricted)")
    func templateSource_alwaysCanStart() {
        var state = WorkoutEditor.State(
            loading: .init(name: "Easy Run", blocks: []),
            asCopy: true, source: .template, isTodaySession: false
        )
        state.watchAvailable = true
        #expect(state.canStartOnWatch == true)
    }
}

// MARK: - PlannedSession.dayOfWeek(for:)

@Suite("PlannedSession.dayOfWeek(for:)")
struct DayOfWeekTests {

    @Test("Friday 2026-06-19 → 5")
    func friday() {
        let utcCal = Calendar(identifier: .gregorian).with(timeZone: .gmt)
        #expect(PlannedSession.dayOfWeek(for: friday2026, calendar: utcCal) == 5)
    }

    @Test("Thursday 2026-06-18 → 4")
    func thursday() {
        let utcCal = Calendar(identifier: .gregorian).with(timeZone: .gmt)
        #expect(PlannedSession.dayOfWeek(for: thursday2026, calendar: utcCal) == 4)
    }
}

// MARK: - WeekSchedule.sessionTapped (Full-Schedule path)
// The reducer — not the view — must compute isToday from date.now so that
// a stale SwiftUI render never produces a wrong isTodaySession in the editor.

@MainActor
@Suite("WeekSchedule — sessionTapped isTodaySession")
struct WeekScheduleSessionTappedTests {

    @Test("Friday session tapped on Friday → delegate openSession with isToday: true")
    func fridaySessionOnFriday_delegateIsToday() async {
        let store = TestStore(initialState: WeekSchedule.State()) {
            WeekSchedule()
        } withDependencies: {
            $0.date.now = friday2026
        }

        let session = fridaySession()
        await store.send(.sessionTapped(session))
        await store.receive(\.delegate, .openSession(session, isToday: true))
    }

    @Test("Friday session tapped on Thursday → delegate openSession with isToday: false")
    func fridaySessionOnThursday_delegateNotToday() async {
        let store = TestStore(initialState: WeekSchedule.State()) {
            WeekSchedule()
        } withDependencies: {
            $0.date.now = thursday2026
        }

        let session = fridaySession()
        await store.send(.sessionTapped(session))
        await store.receive(\.delegate, .openSession(session, isToday: false))
    }

    @Test("Wednesday session tapped on Friday → delegate openSession with isToday: false")
    func wednesdayOnFriday_delegateNotToday() async {
        let store = TestStore(initialState: WeekSchedule.State()) {
            WeekSchedule()
        } withDependencies: {
            $0.date.now = friday2026
        }

        let session = wednesdaySession()
        await store.send(.sessionTapped(session))
        await store.receive(\.delegate, .openSession(session, isToday: false))
    }
}

// MARK: - Calendar helper

private extension Calendar {
    func with(timeZone: TimeZone) -> Calendar {
        var cal = self
        cal.timeZone = timeZone
        return cal
    }
}
