import Foundation
import SQLiteData
import VDOTEngine

@Table public struct PlannedSession: Identifiable, Sendable {
    public let id: UUID
    public var weekId: TrainingWeek.ID
    /// 1 = Monday … 7 = Sunday
    public var dayOfWeek: Int
    public var sessionType: SessionType
    public var targetDistanceKm: Double?
    public var targetDurationMin: Int?
    /// Pace zone the runner should target during the work portion.
    /// Stored at goal-creation time; the actual `PaceRange` is computed
    /// from `targetPaceZone × currentVDOT` at render time so that paces
    /// stay live as the runner's VDOT improves.
    public var targetPaceZone: PaceZoneName?
    /// Free-text note (e.g. "5×1000m" structure hint). Pace text used to
    /// live here but it lied about future weeks — use `targetPaceZone`
    /// instead.
    public var notes: String

    public init(
        id: UUID = UUID(),
        weekId: TrainingWeek.ID,
        dayOfWeek: Int,
        sessionType: SessionType,
        targetDistanceKm: Double? = nil,
        targetDurationMin: Int? = nil,
        targetPaceZone: PaceZoneName? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.weekId = weekId
        self.dayOfWeek = dayOfWeek
        self.sessionType = sessionType
        self.targetDistanceKm = targetDistanceKm
        self.targetDurationMin = targetDurationMin
        self.targetPaceZone = targetPaceZone
        self.notes = notes
    }
}
