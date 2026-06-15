import Foundation

/// The single owner of pace / distance / duration display conventions.
///
/// Before this module existed, the km↔mi constant appeared nine times in
/// three spellings (one of them wrong by 4 ppm) and min:sec formatting was
/// reimplemented seven times across four feature modules. Every caller now
/// asks one question — "format this in the runner's unit" — and gets every
/// convention (conversion, rounding, suffix) included.
public enum PaceFormatting {

    /// The international mile, exactly. The only place this constant lives.
    public static let metresPerMile: Double = 1_609.344

    /// "5:30" — minutes:seconds from a seconds count. Rounds to the
    /// nearest second.
    public static func minutesSeconds(_ totalSeconds: Double) -> String {
        let s = Int(totalSeconds.rounded())
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    /// "12.5 km" / "7.8 mi" — a distance in the runner's unit, one decimal
    /// at most, with the unit suffix.
    public static func distance(metres: Double, unit: PaceUnit) -> String {
        "\(distanceValue(metres: metres, unit: unit).formatted(.number.precision(.fractionLength(0...1)))) \(unit.distanceSuffix)"
    }

    /// The bare converted number for callers that lay out value and unit
    /// separately (hero metrics, chips).
    public static func distanceValue(metres: Double, unit: PaceUnit) -> Double {
        switch unit {
        case .perKilometre: metres / 1_000
        case .perMile:      metres / metresPerMile
        }
    }

    /// "5:30 /km" / "8:51 /mi" — a pace in the runner's unit from the
    /// canonical storage form (seconds per kilometre).
    public static func pace(secondsPerKm: Double, unit: PaceUnit) -> String {
        "\(paceMinutesSeconds(secondsPerKm: secondsPerKm, unit: unit)) \(unit.displayName)"
    }

    /// The "5:30" part alone, unit-converted, for callers that style the
    /// suffix separately.
    public static func paceMinutesSeconds(secondsPerKm: Double, unit: PaceUnit) -> String {
        minutesSeconds(secondsPerKm * unit.paceScaleFromKm)
    }
}

extension PaceUnit {
    /// The runner's preference. Settings is the single writer (via
    /// @AppStorage); SwiftUI views read reactively via @Shared. This
    /// accessor serves non-SwiftUI contexts — App Intents, spoken
    /// summaries — that need the same source of truth without a view
    /// hierarchy.
    public static var current: PaceUnit {
        let raw = UserDefaults.runCraftGroup.string(forKey: "paceUnit") ?? PaceUnit.perKilometre.rawValue
        return PaceUnit(rawValue: raw) ?? .perKilometre
    }

    /// "km" / "mi" — bare distance suffix. (`displayName` is the pace
    /// suffix, "/km" / "/mi".)
    public var distanceSuffix: String {
        switch self {
        case .perKilometre: "km"
        case .perMile:      "mi"
        }
    }

    /// Multiplier converting a seconds-per-km pace into this unit.
    public var paceScaleFromKm: Double {
        switch self {
        case .perKilometre: 1.0
        case .perMile:      PaceFormatting.metresPerMile / 1_000
        }
    }
}
