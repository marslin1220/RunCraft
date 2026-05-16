import Foundation
import SQLiteData

@Table public struct RaceGoal: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var targetDate: Date
    public var distanceKm: Double
    public var currentVDOT: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        targetDate: Date,
        distanceKm: Double,
        currentVDOT: Double = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.targetDate = targetDate
        self.distanceKm = distanceKm
        self.currentVDOT = currentVDOT
        self.createdAt = createdAt
    }

    public var daysUntilRace: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
    }
}
