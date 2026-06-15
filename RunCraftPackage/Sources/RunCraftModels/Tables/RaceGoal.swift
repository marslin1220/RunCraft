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
    /// JSON-encoded `[Int]` of preferred training days (1=Mon...7=Sun).
    /// Decoded on demand via the `availableDays` accessor.
    public var availableDaysData: String = "[1,2,3,4,5,6,7]"
    /// Preferred long-run day (1=Mon...7=Sun), or `nil` for no preference.
    public var longRunDay: Int? = nil

    public init(
        id: UUID = UUID(),
        name: String,
        targetDate: Date,
        distanceKm: Double,
        currentVDOT: Double = 0,
        createdAt: Date = Date(),
        isPlaceholder: Bool = false,
        availableDaysData: String = "[1,2,3,4,5,6,7]",
        longRunDay: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.targetDate = targetDate
        self.distanceKm = distanceKm
        self.currentVDOT = currentVDOT
        self.createdAt = createdAt
        self.isPlaceholder = isPlaceholder
        self.availableDaysData = availableDaysData
        self.longRunDay = longRunDay
    }

    public var daysUntilRace: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
    }

    /// Decoded preferred training days (1=Mon...7=Sun). Falls back to all 7
    /// if the JSON is malformed or empty.
    public var availableDays: Set<Int> {
        get {
            guard let data = availableDaysData.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Int].self, from: data),
                  !decoded.isEmpty
            else { return Set(1...7) }
            return Set(decoded)
        }
        set { availableDaysData = Self.encode(newValue) }
    }

    private static func encode(_ days: Set<Int>) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(days.sorted()),
              let str = String(data: data, encoding: .utf8)
        else { return "[1,2,3,4,5,6,7]" }
        return str
    }
}
