import Foundation
import SQLiteData

public enum TrainingPhase: String, Sendable, Equatable, CaseIterable, Codable, QueryBindable, QueryDecodable {
    case base
    case build
    case peak
    case taper

    public var displayName: String {
        switch self {
        case .base:  String(localized: "Base",  bundle: .module)
        case .build: String(localized: "Build", bundle: .module)
        case .peak:  String(localized: "Peak",  bundle: .module)
        case .taper: String(localized: "Taper", bundle: .module)
        }
    }
}
