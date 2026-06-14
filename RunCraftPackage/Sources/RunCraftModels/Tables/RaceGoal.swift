import Foundation
import SQLiteData

@Table public struct RaceGoal: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var targetDate: Date
    public var distanceKm: Double
    public var currentVDOT: Double
    public var createdAt: Date
    /// True for the "Base Training" row created by Set Up VDOT when the
    /// runner has no race goal yet — a single rolling week reuses the same
    /// plan machinery without a real race to count down to.
    public var isPlaceholder: Bool = false

    public init(
        id: UUID = UUID(),
        name: String,
        targetDate: Date,
        distanceKm: Double,
        currentVDOT: Double = 0,
        createdAt: Date = Date(),
        isPlaceholder: Bool = false
    ) {
        self.id = id
        self.name = name
        self.targetDate = targetDate
        self.distanceKm = distanceKm
        self.currentVDOT = currentVDOT
        self.createdAt = createdAt
        self.isPlaceholder = isPlaceholder
    }

    public var daysUntilRace: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
    }
}
