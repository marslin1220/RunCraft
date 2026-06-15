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

    /// Short explanation of this session type's training purpose, shown in
    /// the Workshop category info popover.
    public var purpose: String {
        switch self {
        case .easy:
            String(localized: "Comfortable, conversational-effort running that builds your aerobic base and helps you recover between harder sessions.", bundle: .module)
        case .tempo:
            String(localized: "Sustained effort at Threshold pace — comfortably hard. Trains your body to clear lactate efficiently so you can hold a strong pace longer.", bundle: .module)
        case .interval:
            String(localized: "Hard repeats at Interval pace with jog recoveries in between. Raises your VO₂max and running economy.", bundle: .module)
        case .long:
            String(localized: "Your week's longest run, at an easy-to-moderate effort. Builds endurance and the resilience to keep going late in a race.", bundle: .module)
        case .repetition:
            String(localized: "Short, fast repeats at Repetition pace with full recovery. Sharpens speed and running form without heavy aerobic load.", bundle: .module)
        case .rest:
            String(localized: "A scheduled day off from running. This is when your body absorbs the training and adapts — skipping it works against you.", bundle: .module)
        case .fartlek:
            String(localized: "Swedish for \"speed play\" — unstructured bursts of faster running mixed into an easy run. Adds variety and teaches you to change gears.", bundle: .module)
        case .mixed:
            String(localized: "A session that blends paces or stimuli in one run — for example easy, marathon, and threshold efforts back to back.", bundle: .module)
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
