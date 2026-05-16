import ComposableArchitecture
import Foundation
import HealthKitClient
import RunCraftModels
import VDOTEngine

@Reducer public struct SetupRaceGoal {
    @ObservableState public struct State: Equatable {
        public var goalName: String = ""
        public var targetDate: Date = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
        public var distanceKm: Double = 21.0

        // HealthKit auto-detection
        public var detectedVDOT: Double? = nil
        public var isDetectingVDOT: Bool = false

        // Manual race time input
        public var manualDistance: RaceDistanceQuery = .fiveK
        public var manualMinutes: String = ""
        public var manualSeconds: String = ""

        public var paceZones: PaceZones? {
            guard let v = effectiveVDOT else { return nil }
            return VDOTCalculator.paceZones(vdot: v)
        }

        /// HealthKit-detected takes priority; falls back to calculated from manual race time.
        public var effectiveVDOT: Double? {
            if let v = detectedVDOT { return v }
            let mins = Int(manualMinutes) ?? 0
            let secs = Int(manualSeconds) ?? 0
            let totalSeconds = Double(mins * 60 + secs)
            guard totalSeconds > 0 else { return nil }
            let v = VDOTCalculator.vdot(distanceMeters: manualDistance.metres, timeSeconds: totalSeconds)
            return v >= 30 ? v : nil
        }

        public var calculatedVDOT: Double? {
            let mins = Int(manualMinutes) ?? 0
            let secs = Int(manualSeconds) ?? 0
            let totalSeconds = Double(mins * 60 + secs)
            guard totalSeconds > 0 else { return nil }
            let v = VDOTCalculator.vdot(distanceMeters: manualDistance.metres, timeSeconds: totalSeconds)
            return v >= 30 ? v : nil
        }

        var canSave: Bool {
            !goalName.isEmpty && effectiveVDOT != nil
        }

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case detectVDOTTapped
        case clearDetectedVDOTTapped
        case vdotDetectionResponse(Result<Double, any Error>)
        case saveButtonTapped
        case cancelButtonTapped
    }

    @Dependency(\.healthKitClient) var healthKitClient
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.date.now) var now

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

            case let .vdotDetectionResponse(.failure(error)):
                state.isDetectingVDOT = false
                _ = error
                return .none

            case .saveButtonTapped:
                guard let vdot = state.effectiveVDOT else { return .none }
                let goal = RaceGoal(
                    name: state.goalName,
                    targetDate: state.targetDate,
                    distanceKm: state.distanceKm,
                    currentVDOT: vdot,
                    createdAt: now
                )
                let (weeks, sessions) = TrainingPlanGenerator.generate(goal: goal, vdot: vdot)
                return .run { [database, dismiss] _ in
                    try await database.write { db in
                        try RaceGoal.upsert { goal }.execute(db)
                        for week in weeks {
                            try TrainingWeek.upsert { week }.execute(db)
                        }
                        for session in sessions {
                            try PlannedSession.upsert { session }.execute(db)
                        }
                    }
                    await dismiss()
                }

            case .cancelButtonTapped:
                return .run { [dismiss] _ in await dismiss() }
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
