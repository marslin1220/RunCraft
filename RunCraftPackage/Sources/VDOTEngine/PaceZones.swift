import Foundation

/// Training pace zones derived from a runner's VDOT score.
/// All paces are expressed in seconds per kilometre.
public struct PaceZones: Equatable, Sendable {
    /// Comfortable aerobic pace for easy runs and long runs.
    public let easy: PaceRange
    /// Target race pace for marathon distance.
    public let marathon: PaceRange
    /// Lactate threshold pace (comfortably hard, ~60 min effort).
    public let threshold: PaceRange
    /// VO2max interval pace (~3-5 min repeats).
    public let interval: PaceRange
    /// Economy repetition pace (short fast reps ≤90 sec).
    public let repetition: PaceRange

    public struct PaceRange: Equatable, Sendable {
        /// Faster bound in seconds per kilometre.
        public let lower: Double
        /// Slower bound in seconds per kilometre.
        public let upper: Double

        public init(lower: Double, upper: Double) {
            self.lower = lower
            self.upper = upper
        }

        /// Returns a formatted string like "6:41 – 7:30 /km".
        public func formatted(unit: PaceUnit = .perKilometre) -> String {
            let scale = unit == .perKilometre ? 1.0 : 1.60934
            let lo = formatSeconds(lower * scale)
            let hi = formatSeconds(upper * scale)
            let suffix = unit == .perKilometre ? "/km" : "/mi"
            if abs(lower - upper) < 1 {
                return "\(lo) \(suffix)"
            }
            return "\(lo) – \(hi) \(suffix)"
        }
    }

    public init(easy: PaceRange, marathon: PaceRange, threshold: PaceRange,
                interval: PaceRange, repetition: PaceRange) {
        self.easy = easy
        self.marathon = marathon
        self.threshold = threshold
        self.interval = interval
        self.repetition = repetition
    }
}

public enum PaceUnit: Sendable {
    case perKilometre
    case perMile
}

private func formatSeconds(_ totalSeconds: Double) -> String {
    let s = Int(totalSeconds.rounded())
    return "\(s / 60):\(String(format: "%02d", s % 60))"
}
