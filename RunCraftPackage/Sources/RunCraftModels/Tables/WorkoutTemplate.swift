import Foundation
import SQLiteData
import VDOTEngine

@Table public struct WorkoutTemplate: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    /// JSON-encoded `[WorkoutBlock]`. Decoded on demand via `blocks` accessor.
    public var blocksData: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        blocks: [WorkoutBlock] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.blocksData = Self.encode(blocks)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Decoded blocks (returns empty array if JSON malformed).
    public var blocks: [WorkoutBlock] {
        get {
            guard let data = blocksData.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([WorkoutBlock].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            blocksData = Self.encode(newValue)
        }
    }

    private static func encode(_ blocks: [WorkoutBlock]) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(blocks),
              let str = String(data: data, encoding: .utf8)
        else { return "[]" }
        return str
    }

    /// Total number of steps across all blocks, expanding repeat groups by
    /// their iteration count.
    public var totalSteps: Int {
        blocks.reduce(0) { acc, block in
            switch block {
            case .step: acc + 1
            case .repeatGroup(let g): acc + g.steps.count * g.iterations
            }
        }
    }

    /// Total distance-goal metres across all blocks, expanding repeat
    /// groups by their iteration count. Steps with a duration (not
    /// distance) goal don't contribute.
    public var estimatedDistanceMetres: Double {
        blocks.reduce(0.0) { acc, block in
            switch block {
            case .step(let s):
                if case .distance(let m) = s.goal { return acc + m }
                return acc
            case .repeatGroup(let g):
                let per = g.steps.reduce(0.0) { sub, s in
                    if case .distance(let m) = s.goal { return sub + m }
                    return sub
                }
                return acc + per * Double(g.iterations)
            }
        }
    }

    /// "≈ X km · N steps" — the canonical human-readable summary shown in
    /// the Workshop list, Siri's entity subtitle, and the Start Workout
    /// snippet.
    public func summary(unit: PaceUnit) -> String {
        var parts: [String] = []
        if estimatedDistanceMetres > 0 {
            parts.append("≈ \(PaceFormatting.distance(metres: estimatedDistanceMetres, unit: unit))")
        }
        parts.append("\(totalSteps) step\(totalSteps == 1 ? "" : "s")")
        return parts.joined(separator: " · ")
    }
}
