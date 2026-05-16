import Foundation
import SQLiteData

public enum TrainingPhase: String, Sendable, Equatable, CaseIterable, Codable, QueryBindable, QueryDecodable {
    case base
    case build
    case peak
    case taper

    public var displayName: String {
        switch self {
        case .base:  "Base"
        case .build: "Build"
        case .peak:  "Peak"
        case .taper: "Taper"
        }
    }
}
