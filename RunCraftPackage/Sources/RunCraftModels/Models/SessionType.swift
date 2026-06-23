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

    /// Session types the runner can substitute for this one, with a short
    /// coaching rationale. Used to populate the context-menu "Swap" options
    /// in the Plan and Full Schedule views.
    public var alternatives: [SessionAlternative] {
        switch self {
        case .repetition:
            [
                SessionAlternative(id: "rep_hill", sessionType: .repetition, title: "Hill Repeats",
                                   reason: "Builds power and form without the speed risk of flat reps.",
                                   variantNote: "Hill repeats — run on 4–6% grade"),
                SessionAlternative(id: "rep_fartlek", sessionType: .fartlek, title: "Fartlek",
                                   reason: "Lower injury risk with a similar aerobic-speed stimulus.",
                                   variantNote: nil),
            ]
        case .interval:
            [
                SessionAlternative(id: "int_hill", sessionType: .interval, title: "Hill Intervals",
                                   reason: "Identical VO₂max benefit with lower ground-impact forces.",
                                   variantNote: "Hill intervals — run on 4–6% grade"),
                SessionAlternative(id: "int_tempo", sessionType: .tempo, title: "Tempo Run",
                                   reason: "Similar lactate-threshold benefit at a more manageable effort.",
                                   variantNote: nil),
                SessionAlternative(id: "int_fartlek", sessionType: .fartlek, title: "Fartlek",
                                   reason: "Unstructured speed play without strict splits.",
                                   variantNote: nil),
            ]
        case .tempo:
            [
                SessionAlternative(id: "tempo_fartlek", sessionType: .fartlek, title: "Fartlek",
                                   reason: "Similar effort profile, less mental pressure than holding steady pace.",
                                   variantNote: nil),
                SessionAlternative(id: "tempo_easy", sessionType: .easy, title: "Easy Run",
                                   reason: "Drop the intensity and treat it as an active-recovery day instead.",
                                   variantNote: "Swapped from Tempo — easy recovery run"),
            ]
        case .long:
            [
                SessionAlternative(id: "long_short", sessionType: .long, title: "Shorter Long Run",
                                   reason: "Maintain the long-run stimulus at 70–80% of planned distance.",
                                   variantNote: "Shorter long run — aim for 70–80% of planned distance"),
                SessionAlternative(id: "long_easy", sessionType: .easy, title: "Easy Run",
                                   reason: "Scale back fully if fatigue or life gets in the way.",
                                   variantNote: "Swapped from Long Run — easy run"),
            ]
        case .easy:
            [
                SessionAlternative(id: "easy_rest", sessionType: .rest, title: "Rest",
                                   reason: "Take the day fully off if you need more recovery.",
                                   variantNote: nil),
            ]
        case .rest:
            [
                SessionAlternative(id: "rest_easy", sessionType: .easy, title: "Easy Run",
                                   reason: "A light session instead of a full day off.",
                                   variantNote: "Optional easy run on rest day"),
            ]
        case .fartlek, .mixed:
            []
        }
    }
}

// MARK: - Session Alternative

/// An alternative session type the runner can substitute for a planned session.
public struct SessionAlternative: Identifiable, Sendable {
    public let id: String
    /// The session type this alternative maps to. May equal the original's
    /// type (e.g. Hill Repeats keeps `.repetition`) — in that case only the
    /// `variantNote` changes.
    public let sessionType: SessionType
    /// Short display name shown in the context menu, e.g. "Hill Repeats".
    public let title: String
    /// One-sentence coaching rationale — displayed in accessibility labels
    /// and future detail views.
    public let reason: String
    /// Stored in `PlannedSession.notes` when this alternative is applied.
    /// `nil` means the existing notes are cleared.
    public let variantNote: String?
}
