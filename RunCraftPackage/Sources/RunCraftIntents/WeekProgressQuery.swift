import Dependencies
import Foundation
import RunCraftModels
import SQLiteData

/// Aggregated training volume for the current calendar week.
/// Used by the Today widget to drive a weekly-progress bar.
public struct WeekProgressData: Sendable, Equatable {
    public let sessionsDone: Int
    public let sessionsPlanned: Int
    public let kmDone: Double
    public let kmTarget: Double

    /// 0–1, used directly as `ProgressView(value:)`.
    public var ratio: Double {
        guard kmTarget > 0 else {
            guard sessionsPlanned > 0 else { return 0 }
            return min(Double(sessionsDone) / Double(sessionsPlanned), 1.0)
        }
        return min(kmDone / kmTarget, 1.0)
    }

    public static let empty = WeekProgressData(
        sessionsDone: 0, sessionsPlanned: 0, kmDone: 0, kmTarget: 0
    )
    public static let placeholder = WeekProgressData(
        sessionsDone: 3, sessionsPlanned: 4, kmDone: 24, kmTarget: 38
    )
}

/// Loads the current week's progress from the shared App Group database.
/// Returns `.empty` on any error — callers must not crash on failures.
public func loadWeekProgress() async -> WeekProgressData {
    let database: any DatabaseWriter = Dependencies.Dependency(\.defaultDatabase).wrappedValue
    let calendar = Calendar.current
    guard
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
        let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)
    else { return .empty }

    return (try? await database.read { db -> WeekProgressData in
        let weeks = try TrainingWeek.all.fetchAll(db)
        guard let currentWeek = TrainingWeek.current(in: weeks) else { return .empty }

        let allSessions = try PlannedSession
            .where { $0.weekId.eq(currentWeek.id) }
            .fetchAll(db)
        let sessionsPlanned = allSessions.filter { $0.sessionType != .rest }.count

        let allWorkouts = try CompletedWorkout
            .order { $0.completedAt.desc() }
            .fetchAll(db)
        let thisWeek = allWorkouts.filter {
            $0.completedAt >= weekStart && $0.completedAt < weekEnd
        }

        return WeekProgressData(
            sessionsDone: thisWeek.count,
            sessionsPlanned: sessionsPlanned,
            kmDone: thisWeek.reduce(0) { $0 + $1.actualDistanceKm },
            kmTarget: currentWeek.targetWeeklyKm
        )
    }) ?? .empty
}
