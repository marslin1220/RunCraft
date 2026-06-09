import ComposableArchitecture
import Foundation
import HealthKitClient
import VDOTEngine

@Reducer public struct Settings {
    @ObservableState public struct State: Equatable {
        /// Mirrors UserDefaults so the rest of the app's @Shared
        /// observers stay in sync. The actual write happens via
        /// @AppStorage in SettingsView — keeping it out of TCA state
        /// avoids BindingReducer + @Shared interaction quirks.
        @Shared(.appStorage("healthKitLinked"))
        public var hasLinkedHealthKit: Bool = false

        public init() {}
    }

    public enum Action {
        case onAppear
        case linkHealthKitTapped
        case healthKitAuthResponse(Result<Void, any Error>)
    }

    @Dependency(\.healthKitClient) var healthKitClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case .linkHealthKitTapped:
                return .run { [healthKitClient] send in
                    await send(.healthKitAuthResponse(Result {
                        try await healthKitClient.requestAuthorization()
                    }))
                }

            case .healthKitAuthResponse(.success):
                state.$hasLinkedHealthKit.withLock { $0 = true }
                return .none

            case .healthKitAuthResponse(.failure):
                return .none
            }
        }
    }
}
