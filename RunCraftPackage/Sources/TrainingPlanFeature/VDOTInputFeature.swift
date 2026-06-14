import ComposableArchitecture
import Foundation
import HealthKitClient
import RunCraftModels
import VDOTEngine

/// VDOT detection + manual race-time entry, shared by `SetupRaceGoalFeature`
/// (race goal + VDOT) and `SetupVDOTFeature` (VDOT only, "Base Training").
@Reducer public struct VDOTInput {
    @ObservableState public struct State: Equatable {
        // HealthKit auto-detection
        public var detectedVDOT: Double? = nil
        public var isDetectingVDOT: Bool = false

        // Manual race time input
        public var manualDistance: RaceDistanceQuery = .fiveK
        public var manualMinutes: Int = 0
        public var manualSeconds: Int = 0

        public init() {}

        /// Seeds the detected-VDOT pill so the form starts in a valid
        /// (saveable) state — user can clear it if they want to re-enter
        /// a new race time.
        public init(detectedVDOT: Double?) {
            self.detectedVDOT = detectedVDOT
        }

        public var calculatedVDOT: Double? {
            let totalSeconds = Double(manualMinutes * 60 + manualSeconds)
            guard totalSeconds > 0 else { return nil }
            let v = VDOTCalculator.vdot(distanceMeters: manualDistance.metres, timeSeconds: totalSeconds)
            return v >= 30 ? v : nil
        }

        /// HealthKit-detected takes priority; falls back to calculated from manual race time.
        public var effectiveVDOT: Double? {
            detectedVDOT ?? calculatedVDOT
        }

        public var paceZones: PaceZones? {
            guard let v = effectiveVDOT else { return nil }
            return VDOTCalculator.paceZones(vdot: v)
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case detectVDOTTapped
        case clearDetectedVDOTTapped
        case vdotDetectionResponse(Result<Double, any Error>)
    }

    @Dependency(\.healthKitClient) var healthKitClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .clearDetectedVDOTTapped:
                state.detectedVDOT = nil
                return .none

            case .detectVDOTTapped:
                state.isDetectingVDOT = true
                return .run { [healthKitClient] send in
                    await send(.vdotDetectionResponse(Result {
                        try await healthKitClient.requestAuthorization()
                        var bestVDOT: Double = 0
                        for query in [RaceDistanceQuery.fiveK, .tenK, .halfMarathon] {
                            if let time = try await healthKitClient.bestRaceTime(query) {
                                let v = VDOTCalculator.vdot(distanceMeters: query.metres, timeSeconds: time)
                                bestVDOT = max(bestVDOT, v)
                            }
                        }
                        guard bestVDOT > 0 else { throw HealthKitError.noRaceDataFound }
                        return bestVDOT
                    }))
                }

            case let .vdotDetectionResponse(.success(vdot)):
                state.isDetectingVDOT = false
                state.detectedVDOT = vdot
                return .none

            case .vdotDetectionResponse(.failure):
                state.isDetectingVDOT = false
                return .none
            }
        }
    }
}

public enum HealthKitError: LocalizedError {
    case noRaceDataFound

    public var errorDescription: String? {
        switch self {
        case .noRaceDataFound:
            "No running workouts found. Please enter your VDOT manually."
        }
    }
}
