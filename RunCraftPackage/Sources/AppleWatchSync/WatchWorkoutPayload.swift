import Foundation
import RunCraftModels

/// Everything `WorkoutPlanBuilder.makePlan(name:blocks:)` needs, sent from
/// iPhone to the paired Apple Watch over `WCSession`.
///
/// Deliberately not `WorkoutTemplate` — that's a SQLiteData `@Table` row
/// with `id`/`blocksData`/`createdAt`/`updatedAt` the watch doesn't need,
/// and isn't `Codable`. This is the minimal cross-device wire format.
public struct WatchWorkoutPayload: Codable, Sendable, Equatable {
    public var name: String
    /// Optional display hint — e.g. "5:10 – 5:30 /km" for pace-zone templates.
    /// Absent from workout-editor payloads; nil decodes cleanly from older JSON.
    public var subtitle: String?
    /// Jack Daniels zone letter (E / M / T / I / R) for pace-zone templates.
    /// Nil for regular workout payloads. Decodes as nil from older JSON.
    public var zoneLetter: String?
    public var blocks: [WorkoutBlock]

    public init(name: String, subtitle: String? = nil, zoneLetter: String? = nil, blocks: [WorkoutBlock]) {
        self.name = name
        self.subtitle = subtitle
        self.zoneLetter = zoneLetter
        self.blocks = blocks
    }
}
