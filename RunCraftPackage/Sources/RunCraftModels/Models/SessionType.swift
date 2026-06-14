import Foundation
import SQLiteData

public enum SessionType: String, Sendable, Equatable, CaseIterable, Codable, QueryBindable, QueryDecodable {
    case easy
    case tempo
    case interval
    case long
    case repetition
    case rest
    /// Speed-play session — varied surges and floats (e.g. Mona Fartlek).
    /// Never produced by `TrainingPlanGenerator`; used to categorise
    /// Workshop presets.
    case fartlek
    /// Combination session spanning more than one pace zone (e.g.
    /// Progression Run). Default category for Workshop presets that
    /// don't fit a single zone.
    case mixed

    public var displayName: String {
        switch self {
        case .easy:       String(localized: "Easy Run",   bundle: .module)
        case .tempo:      String(localized: "Tempo Run",  bundle: .module)
        case .interval:   String(localized: "Intervals",  bundle: .module)
        case .long:       String(localized: "Long Run",   bundle: .module)
        case .repetition: String(localized: "Repetitions", bundle: .module)
        case .rest:       String(localized: "Rest",       bundle: .module)
        case .fartlek:    String(localized: "Fartlek",    bundle: .module)
        case .mixed:      String(localized: "Mixed",      bundle: .module)
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
        case .fartlek:    "#9C27B0"  // purple
        case .mixed:      "#607D8B"  // blue grey
        }
    }

    /// SF Symbol used as the leading icon on a session row. Outlined /
    /// stroke style so it reads as "instrument" rather than competing
    /// with the lime accent.
    public var symbolName: String {
        switch self {
        case .easy:       "figure.run"
        case .tempo:      "bolt"
        case .interval:   "flame"
        case .long:       "figure.run.circle"
        case .repetition: "arrow.up.right"
        case .rest:       "moon.zzz"
        case .fartlek:    "shuffle"
        case .mixed:      "square.stack.3d.up"
        }
    }
}
