import Foundation
import SQLiteData

public enum SessionType: String, Sendable, Equatable, CaseIterable, Codable, QueryBindable, QueryDecodable {
    case easy
    case tempo
    case interval
    case long
    case repetition
    case rest

    public var displayName: String {
        switch self {
        case .easy:       "Easy Run"
        case .tempo:      "Tempo Run"
        case .interval:   "Intervals"
        case .long:       "Long Run"
        case .repetition: "Repetitions"
        case .rest:       "Rest"
        }
    }

    /// Hex colour for UI intensity indication.
    public var colorHex: String {
        switch self {
        case .easy:       "#4CAF50"  // green
        case .tempo:      "#FFC107"  // amber
        case .interval:   "#F44336"  // red
        case .long:       "#2196F3"  // blue
        case .repetition: "#FF5722"  // deep orange
        case .rest:       "#9E9E9E"  // grey
        }
    }
}
