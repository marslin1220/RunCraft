import Foundation
import SQLiteData

/// A point-in-time record of the runner's VDOT. Written whenever VDOT
/// changes (initial estimate, race-time recompute, adaptive upgrade,
/// manual edit) so the Insights tab can draw a trend line.
@Table public struct VDOTSnapshot: Identifiable, Sendable {
    public let id: UUID
    public var vdot: Double
    public var recordedAt: Date
    public var source: Source

    public enum Source: String, Sendable, Equatable, CaseIterable, Codable,
                        QueryBindable, QueryDecodable {
        case initial
        case raceTime
        case overperformance
        case manual
    }

    public init(
        id: UUID = UUID(),
        vdot: Double,
        recordedAt: Date = Date(),
        source: Source
    ) {
        self.id = id
        self.vdot = vdot
        self.recordedAt = recordedAt
        self.source = source
    }
}
