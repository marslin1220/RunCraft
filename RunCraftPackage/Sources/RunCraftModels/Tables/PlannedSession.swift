import Foundation
import SQLiteData

@Table public struct PlannedSession: Identifiable, Sendable {
    public let id: UUID
    public var weekId: TrainingWeek.ID
    /// 1 = Monday … 7 = Sunday
    public var dayOfWeek: Int
    public var sessionType: SessionType
    public var targetDistanceKm: Double?
    public var targetDurationMin: Int?
    public var notes: String

    public init(
        id: UUID = UUID(),
        weekId: TrainingWeek.ID,
        dayOfWeek: Int,
        sessionType: SessionType,
        targetDistanceKm: Double? = nil,
        targetDurationMin: Int? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.weekId = weekId
        self.dayOfWeek = dayOfWeek
        self.sessionType = sessionType
        self.targetDistanceKm = targetDistanceKm
        self.targetDurationMin = targetDurationMin
        self.notes = notes
    }
}
