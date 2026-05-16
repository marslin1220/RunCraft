import Foundation

public enum RaceDistance: Sendable, Equatable, Codable {
    case fiveK
    case tenK
    case halfMarathon
    case custom(Double)  // kilometres

    public var metres: Double {
        switch self {
        case .fiveK:        5_000
        case .tenK:         10_000
        case .halfMarathon: 21_097
        case .custom(let km): km * 1_000
        }
    }

    public var displayName: String {
        switch self {
        case .fiveK:           "5K"
        case .tenK:            "10K"
        case .halfMarathon:    "Half Marathon"
        case .custom(let km):  "\(km, format: .number.precision(.fractionLength(0...1))) km"
        }
    }
}
