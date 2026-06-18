#if os(iOS)
import ActivityKit
import Foundation

public struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var stepName: String
        public var stepGoalText: String
        public var stepProgress: Double
        public var heartRate: Double
        public var paceSecPerKm: Double
        public var totalMetres: Double
        public var elapsedSeconds: Int
        public var isPaused: Bool
        public var isPerMile: Bool

        public init(
            stepName: String,
            stepGoalText: String,
            stepProgress: Double,
            heartRate: Double,
            paceSecPerKm: Double,
            totalMetres: Double,
            elapsedSeconds: Int,
            isPaused: Bool,
            isPerMile: Bool
        ) {
            self.stepName = stepName
            self.stepGoalText = stepGoalText
            self.stepProgress = stepProgress
            self.heartRate = heartRate
            self.paceSecPerKm = paceSecPerKm
            self.totalMetres = totalMetres
            self.elapsedSeconds = elapsedSeconds
            self.isPaused = isPaused
            self.isPerMile = isPerMile
        }

        public var heartRateText: String {
            heartRate > 0 ? "\(Int(heartRate))" : "--"
        }

        public var paceText: String {
            guard paceSecPerKm > 0 else { return "--:--" }
            let sec = isPerMile ? paceSecPerKm * 1.60934 : paceSecPerKm
            return String(format: "%d:%02d", Int(sec) / 60, Int(sec) % 60)
        }

        public var paceUnitLabel: String { isPerMile ? "/mi" : "/km" }

        public var elapsedTimeText: String {
            let h = elapsedSeconds / 3600
            let m = (elapsedSeconds % 3600) / 60
            let s = elapsedSeconds % 60
            return h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%d:%02d", m, s)
        }

        public var distanceText: String {
            if isPerMile {
                let miles = totalMetres / 1609.34
                return miles >= 0.1
                    ? String(format: "%.2f mi", miles)
                    : String(format: "%.0f ft", totalMetres * 3.28084)
            }
            if totalMetres >= 1000 {
                return String(format: "%.2f km", totalMetres / 1000)
            }
            return "\(Int(totalMetres)) m"
        }
    }

    public var workoutName: String

    public init(workoutName: String) {
        self.workoutName = workoutName
    }
}

extension WorkoutActivityAttributes.ContentState {
    public static func from(
        message: WorkoutMirrorMessage,
        isPerMile: Bool
    ) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            stepName: message.stepName,
            stepGoalText: message.stepGoalText,
            stepProgress: message.stepProgress,
            heartRate: message.heartRate,
            paceSecPerKm: message.paceSecPerKm,
            totalMetres: message.totalMetres,
            elapsedSeconds: message.elapsedSeconds,
            isPaused: message.isPaused,
            isPerMile: isPerMile
        )
    }
}
#endif
