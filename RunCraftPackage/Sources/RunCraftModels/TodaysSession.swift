import Foundation
import SQLiteData

/// Today's planned session plus the VDOT to use for pace-zone/template
/// generation. Single source of truth for "what is today's session?" —
/// used by `TodaySessionQuery` (Siri/Spotlight/Apple Intelligence),
/// `StartTodaysSessionIntent`, and the Today's-session widget's timeline
/// provider.
public struct TodaysSession: Sendable, Equatable {
    public let session: PlannedSession
    public let vdot: Double

    public init(session: PlannedSession, vdot: Double) {
        self.session = session
        self.vdot = vdot
    }

    /// Looks up the `PlannedSession` whose week contains `date`, paired with
    /// the most recently created `RaceGoal`'s `currentVDOT`. Returns `nil`
    /// if there's no race goal yet, or `date`'s day-of-week has no scheduled
    /// session.
    public static func current(
        in db: Database,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> TodaysSession? {
        let dayOfWeek = PlannedSession.dayOfWeek(for: date, calendar: calendar)
        let weeks = try TrainingWeek.all.fetchAll(db)
        guard let week = TrainingWeek.current(in: weeks, at: date, calendar: calendar) else { return nil }

        let session = try PlannedSession
            .where { $0.weekId.eq(week.id) }
            .where { $0.dayOfWeek.eq(dayOfWeek) }
            .fetchOne(db)
        guard let session else { return nil }

        let goal = try RaceGoal.order { $0.createdAt.desc() }.fetchOne(db)
        return TodaysSession(session: session, vdot: goal?.currentVDOT ?? 40)
    }
}
