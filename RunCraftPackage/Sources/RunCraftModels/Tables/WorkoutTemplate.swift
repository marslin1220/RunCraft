import Foundation
import SQLiteData

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
}
