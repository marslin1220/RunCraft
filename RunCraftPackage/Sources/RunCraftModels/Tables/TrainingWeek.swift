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
}
