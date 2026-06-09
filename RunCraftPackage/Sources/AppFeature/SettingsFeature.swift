import ComposableArchitecture
import Foundation
import HealthKitClient
import VDOTEngine

@Reducer public struct Settings {
    @ObservableState public struct State: Equatable {
        /// User-selected pace unit. Persisted to AppStorage via @Shared so
        /// every view that formats a pace range can pick it up without
        /// prop-drilling. Default: per-kilometre.
        @Shared(.appStorage("paceUnit"))
        public var paceUnit: PaceUnit = .perKilometre
        public var isHealthKitLinked: Bool = false

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
                return .run { [healthKitClient] send in
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
