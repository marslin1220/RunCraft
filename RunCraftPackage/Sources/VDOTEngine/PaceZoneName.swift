import Foundation

/// The five Jack Daniels training pace zones.
///
/// Lives in VDOTEngine because zones are intrinsic to the formula:
/// a zone × a VDOT produces a `PaceRange`. Kept separate from
/// `RunCraftModels.SessionType` (which classifies daily plan sessions
/// — a similar but distinct concept; see UBIQUITOUS_LANGUAGE.md).
public enum PaceZoneName: String, CaseIterable, Equatable, Sendable, Codable {
    case easy
    case marathon
    case threshold
    case interval
    case repetition

    public var letter: String {
        switch self {
        case .easy:       "E"
        case .marathon:   "M"
        case .threshold:  "T"
        case .interval:   "I"
        case .repetition: "R"
        }
    }

    public var displayName: String {
        switch self {
        case .easy:       "Easy"
        case .marathon:   "Marathon"
        case .threshold:  "Threshold"
        case .interval:   "Interval"
        case .repetition: "Repetition"
        }
    }
}

// MARK: - PaceZones subscript by zone

extension PaceZones {
    /// Indexed access by zone so callers can iterate `PaceZoneName.allCases`
    /// instead of writing one expression per zone.
    public subscript(zone: PaceZoneName) -> PaceRange {
        switch zone {
        case .easy:       easy
        case .marathon:   marathon
        case .threshold:  threshold
        case .interval:   interval
        case .repetition: repetition
        }
    }
}
