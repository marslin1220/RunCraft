import AppleWatchSync
import ComposableArchitecture
import Foundation
import RunCraftModels

/// Read-only preview of a workout with a Start button at the bottom.
/// Source determines whether Duplicate is available and how Edit behaves.
@Reducer public struct WorkoutDetail {
    @ObservableState public struct State: Equatable {
        public var workout: WorkoutTemplate
        public var source: Source
        public var syncStatus: SyncStatus = .idle
        @Presents public var alert: AlertState<Action.Alert>?

        public init(workout: WorkoutTemplate, source: Source) {
            self.workout = workout
            self.source = source
        }

        public enum SyncStatus: Equatable {
            case idle
            case sending
            case sent
            case failed(String)
        }
    }

    public enum Source: Equatable {
        case yours          // existing user-owned template; can edit in place
        case template       // built-in preset; Edit creates a working copy
        case planSession    // plan-generated session; Edit creates a working copy
    }

    public enum Action {
        case startTapped
        case syncResponse(Result<Void, any Error>)
        case editTapped
        case duplicateTapped
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {}
        public enum Delegate: Equatable {
            /// Parent should push the editor with this template.
            case requestEdit(WorkoutTemplate)
            /// Parent should insert this template as a new "Yours" row.
            case requestDuplicate(WorkoutTemplate)
        }
    }

    @Dependency(\.workoutKitClient) var workoutKitClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startTapped:
                state.syncStatus = .sending
                let workout = state.workout
                return .run { [workoutKitClient] send in
                    await send(.syncResponse(Result {
                        _ = try await workoutKitClient.requestAuthorization()
                        try await workoutKitClient.openInWorkoutApp(workout)
                    }))
                }

            case .syncResponse(.success):
                state.syncStatus = .sent
                return .none

            case let .syncResponse(.failure(error)):
                let message = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                state.syncStatus = .failed(message)
                state.alert = AlertState {
                    TextState("Couldn't send to Watch")
                } message: {
                    TextState(message)
                }
                return .none

            case .editTapped:
                return .send(.delegate(.requestEdit(state.workout)))

            case .duplicateTapped:
                return .send(.delegate(.requestDuplicate(state.workout)))

            case .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
