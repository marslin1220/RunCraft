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

    /// Total distance across all blocks (in metres), expanding repeat groups
    /// by their iteration count. For `.time`-goal steps, distance is derived
    /// from the step's `.paceRange` alert (if any).
    public var estimatedDistanceMetres: Double { totals.metres }

    /// Total duration across all blocks (in seconds), expanding repeat groups
    /// by their iteration count. For `.distance`-goal steps, duration is
    /// derived from the step's `.paceRange` alert (if any).
    public var estimatedDurationSeconds: Double { totals.seconds }

    /// "≈ X km · ~Y min · N steps" — the canonical human-readable summary
    /// shown in the Workshop list, Siri's entity subtitle, and the Start
    /// Workout snippet.
    public func summary(unit: PaceUnit) -> String {
        var parts: [String] = []
        if estimatedDistanceMetres > 0 {
            parts.append("≈ \(PaceFormatting.distance(metres: estimatedDistanceMetres, unit: unit))")
        }
        if estimatedDurationSeconds > 0 {
            parts.append("~\(Int((estimatedDurationSeconds / 60).rounded())) min")
        }
        parts.append("\(totalSteps) step\(totalSteps == 1 ? "" : "s")")
        return parts.joined(separator: " · ")
    }

    /// `(metres, seconds)` totals across all blocks, expanding repeat groups
    /// by their iteration count.
    private var totals: (metres: Double, seconds: Double) {
        var metres = 0.0
        var seconds = 0.0
        for block in blocks {
            switch block {
            case .step(let s):
                let t = Self.metresAndSeconds(for: s)
                metres += t.metres
                seconds += t.seconds
            case .repeatGroup(let g):
                for s in g.steps {
                    let t = Self.metresAndSeconds(for: s)
                    metres += t.metres * Double(g.iterations)
                    seconds += t.seconds * Double(g.iterations)
                }
            }
        }
        return (metres, seconds)
    }

    /// Converts a step's goal into `(metres, seconds)`, deriving whichever
    /// dimension isn't directly specified from the step's `.paceRange` alert
    /// (if any) via its midpoint pace. Steps with no pace info (nil or
    /// `.heartRate` alert) contribute only their native goal dimension.
    private static func metresAndSeconds(for step: WorkoutStep) -> (metres: Double, seconds: Double) {
        guard case .paceRange(let lo, let hi)? = step.alert else {
            switch step.goal {
            case .distance(let m): return (m, 0)
            case .time(let s): return (0, Double(s))
            case .openEnded: return (0, 0)
            }
        }
        let secPerKm = Double(lo + hi) / 2
        switch step.goal {
        case .distance(let m): return (m, m / 1_000 * secPerKm)
        case .time(let s): return (Double(s) / secPerKm * 1_000, Double(s))
        case .openEnded: return (0, 0)
        }
    }
}
