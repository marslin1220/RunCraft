import Foundation
import SQLiteData

@Table public struct TrainingWeek: Identifiable, Sendable {
    public let id: UUID
    public var raceGoalId: RaceGoal.ID
    public var weekNumber: Int
    public var phase: TrainingPhase
    public var startDate: Date
    public var targetWeeklyKm: Double

    public init(
        id: UUID = UUID(),
        raceGoalId: RaceGoal.ID,
        weekNumber: Int,
        phase: TrainingPhase,
        startDate: Date,
        targetWeeklyKm: Double
    ) {
        self.id = id
        self.raceGoalId = raceGoalId
        self.weekNumber = weekNumber
        self.phase = phase
        self.startDate = startDate
        self.targetWeeklyKm = targetWeeklyKm
    }

    /// The week that contains `date` (a week runs for 7 days starting at its
    /// `startDate`). Returns `nil` if no week covers the date. Single source
    /// of truth for "which week is today in?" used by both the Plan tab and
    /// the Workshop's Plan segment.
    public static func current(
        in weeks: [TrainingWeek],
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> TrainingWeek? {
        weeks.first { week in
            guard let nextStart = calendar.date(byAdding: .weekOfYear, value: 1, to: week.startDate) else {
                return false
            }
            return week.startDate <= date && date < nextStart
        }
    }
}
