import Foundation
import SQLiteData

@Table public struct CompletedWorkout: Identifiable, Sendable {
    public let id: UUID
    public var plannedSessionId: PlannedSession.ID?
    public var hkWorkoutId: String?
    public var completedAt: Date
    public var actualDistanceKm: Double
    public var actualDurationSec: Double
    public var avgPaceSecPerKm: Double
    /// < 1.0 means faster than target, > 1.0 means slower than target.
    public var paceAchievementRatio: Double

    public init(
        id: UUID = UUID(),
        plannedSessionId: PlannedSession.ID? = nil,
        hkWorkoutId: String? = nil,
        completedAt: Date = Date(),
        actualDistanceKm: Double,
        actualDurationSec: Double,
        avgPaceSecPerKm: Double,
        paceAchievementRatio: Double = 1.0
    ) {
        self.id = id
        self.plannedSessionId = plannedSessionId
        self.hkWorkoutId = hkWorkoutId
        self.completedAt = completedAt
        self.actualDistanceKm = actualDistanceKm
        self.actualDurationSec = actualDurationSec
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.paceAchievementRatio = paceAchievementRatio
    }
}
