import Foundation

/// Sent from Watch → iPhone once per step change (and on metric updates)
/// via `HKWorkoutSession.sendToRemoteWorkoutSession(data:)`.
public struct WorkoutMirrorMessage: Codable, Sendable {
    public var stepName: String
    public var stepGoalText: String
    public var stepProgress: Double
    public var heartRate: Double
    public var paceSecPerKm: Double
    public var totalMetres: Double
    public var elapsedSeconds: Int
    public var isPaused: Bool

    public init(
        stepName: String,
        stepGoalText: String,
        stepProgress: Double,
        heartRate: Double,
        paceSecPerKm: Double,
        totalMetres: Double,
        elapsedSeconds: Int,
        isPaused: Bool
    ) {
        self.stepName = stepName
        self.stepGoalText = stepGoalText
        self.stepProgress = stepProgress
        self.heartRate = heartRate
        self.paceSecPerKm = paceSecPerKm
        self.totalMetres = totalMetres
        self.elapsedSeconds = elapsedSeconds
        self.isPaused = isPaused
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
