import Foundation

/// Sent from Watch → iPhone once per step change (and on metric updates)
/// via `HKWorkoutSession.sendToRemoteWorkoutSession(data:)`.
public struct WorkoutMirrorMessage: Codable, Sendable, Equatable {
    public var stepName: String
    public var stepGoalText: String
    public var stepProgress: Double
    public var heartRate: Double
    public var avgHeartRate: Double
    public var paceSecPerKm: Double
    public var avgPaceSecPerKm: Double
    /// Lower bound of the target pace range (sec/km). `nil` when the current step has no pace alert.
    public var targetPaceLo: Int?
    /// Upper bound of the target pace range (sec/km). `nil` when the current step has no pace alert.
    public var targetPaceHi: Int?
    public var totalMetres: Double
    public var elapsedSeconds: Int
    public var isPaused: Bool
    /// Current HR zone (1–5), or 0 when heart rate data is unavailable.
    public var hrZone: Int

    public init(
        stepName: String,
        stepGoalText: String,
        stepProgress: Double,
        heartRate: Double,
        avgHeartRate: Double = 0,
        paceSecPerKm: Double,
        avgPaceSecPerKm: Double = 0,
        targetPaceLo: Int? = nil,
        targetPaceHi: Int? = nil,
        totalMetres: Double,
        elapsedSeconds: Int,
        isPaused: Bool,
        hrZone: Int = 0
    ) {
        self.stepName = stepName
        self.stepGoalText = stepGoalText
        self.stepProgress = stepProgress
        self.heartRate = heartRate
        self.avgHeartRate = avgHeartRate
        self.paceSecPerKm = paceSecPerKm
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.targetPaceLo = targetPaceLo
        self.targetPaceHi = targetPaceHi
        self.totalMetres = totalMetres
        self.elapsedSeconds = elapsedSeconds
        self.isPaused = isPaused
        self.hrZone = hrZone
    }
}

/// Sent from iPhone → Watch via the mirrored `HKWorkoutSession`.
public struct WorkoutMirrorCommand: Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case pause, resume, end
    }
    public var kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }
}
