import ComposableArchitecture
import Foundation
import HealthKitClient

@Reducer public struct Settings {
    @ObservableState public struct State: Equatable {
        public var paceUnit: PaceUnit = .perKilometre
        public var isHealthKitLinked: Bool = false

        public enum PaceUnit: String, CaseIterable, Equatable {
            case perKilometre = "km"
            case perMile = "mi"

            var displayName: String {
                switch self {
                case .perKilometre: "/km"
                case .perMile:      "/mi"
                }
            }
        }

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case linkHealthKitTapped
        case healthKitAuthResponse(Result<Void, any Error>)
    }

    @Dependency(\.healthKitClient) var healthKitClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .none

            case .linkHealthKitTapped:
                return .run { send in
                    await send(.healthKitAuthResponse(Result {
                        try await healthKitClient.requestAuthorization()
                    }))
                }

            case .healthKitAuthResponse(.success):
                state.isHealthKitLinked = true
                return .none

            case .healthKitAuthResponse(.failure):
                state.isHealthKitLinked = false
                return .none
            }
        }
    }
}
