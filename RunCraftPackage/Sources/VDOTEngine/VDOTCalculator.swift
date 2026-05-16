import Foundation

/// Implements Jack Daniels' VDOT running formula.
///
/// Reference: Daniels, J. (2014). *Daniels' Running Formula* (3rd ed.).
/// Formula source: https://www.vo2maxrunning.com/vdot-calculator
public struct VDOTCalculator {

    // MARK: - VDOT from race performance

    /// Calculates VDOT from a race result.
    ///
    /// - Parameters:
    ///   - distanceMeters: Race distance in metres (e.g. 5000 for 5K).
    ///   - timeSeconds: Finishing time in seconds.
    /// - Returns: VDOT value, clamped to [30, 85].
    public static func vdot(distanceMeters: Double, timeSeconds: Double) -> Double {
        let timeMinutes = timeSeconds / 60.0
        let velocityMPM = distanceMeters / timeMinutes  // metres per minute

        let vo2 = oxygenCost(at: velocityMPM)
        let fraction = vo2MaxFraction(at: timeMinutes)

        let raw = vo2 / fraction
        return min(max(raw, 30), 85)
    }

    // MARK: - Pace zones from VDOT

    /// Derives the five Jack Daniels training pace zones from a VDOT score.
    ///
    /// Percentages calibrated against published VDOT tables:
    /// - E:  54–63 % of VO2max
    /// - M:  73 % of VO2max
    /// - T:  82 % of VO2max (±5 sec/km)
    /// - I:  91 % of VO2max
    /// - R:  97 % of VO2max
    public static func paceZones(vdot: Double) -> PaceZones {
        let vdot = min(max(vdot, 30), 85)

        let easyFast   = pace(forVO2Fraction: 0.63, of: vdot)
        let easySlow   = pace(forVO2Fraction: 0.54, of: vdot)
        let marathon   = pace(forVO2Fraction: 0.73, of: vdot)
        let threshold  = pace(forVO2Fraction: 0.82, of: vdot)
        let interval   = pace(forVO2Fraction: 0.91, of: vdot)
        let repetition = pace(forVO2Fraction: 0.97, of: vdot)

        return PaceZones(
            easy:       .init(lower: easyFast, upper: easySlow),
            marathon:   .init(lower: marathon - 5, upper: marathon + 5),
            threshold:  .init(lower: threshold - 5, upper: threshold + 5),
            interval:   .init(lower: interval - 3, upper: interval + 3),
            repetition: .init(lower: repetition - 3, upper: repetition + 3)
        )
    }

    // MARK: - Internal formula helpers

    /// Oxygen cost (VO2, ml/kg/min) at a given running velocity.
    ///
    /// Formula: VO2 = -4.60 + 0.182258·V + 0.000104·V²
    /// where V is velocity in metres per minute.
    static func oxygenCost(at velocityMPM: Double) -> Double {
        -4.60 + 0.182258 * velocityMPM + 0.000104 * velocityMPM * velocityMPM
    }

    /// Fraction of VO2max sustainable at a given race duration.
    ///
    /// Formula: 0.8 + 0.1894393·e^(-0.012778·T) + 0.2989558·e^(-0.1932605·T)
    /// where T is duration in minutes.
    static func vo2MaxFraction(at durationMinutes: Double) -> Double {
        0.8
        + 0.1894393 * exp(-0.012778 * durationMinutes)
        + 0.2989558 * exp(-0.1932605 * durationMinutes)
    }

    /// Solves for the velocity (m/min) that produces the given VO2, then
    /// converts to pace in seconds per kilometre.
    ///
    /// Quadratic: 0.000104·V² + 0.182258·V + (-4.60 - targetVO2) = 0
    static func pace(forVO2Fraction fraction: Double, of vdot: Double) -> Double {
        let targetVO2 = fraction * vdot
        let a = 0.000104
        let b = 0.182258
        let c = -4.60 - targetVO2
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return 600 }
        let velocityMPM = (-b + sqrt(discriminant)) / (2 * a)
        guard velocityMPM > 0 else { return 600 }
        return 60_000.0 / velocityMPM  // seconds per km
    }
}
