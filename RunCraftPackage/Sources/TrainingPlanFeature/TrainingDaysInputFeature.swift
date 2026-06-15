import ComposableArchitecture
import Foundation

/// Preferred training days (1=Mon...7=Sun) + optional long-run day, shared by
/// `SetupRaceGoalFeature` (initial setup / edit) and `AdjustTrainingDaysFeature`
/// (standalone mid-plan sheet).
@Reducer public struct TrainingDaysInput {
    @ObservableState public struct State: Equatable {
        public var availableDays: Set<Int> = Set(1...7)
        public var longRunDay: Int? = nil

        public init() {}

        public init(availableDays: Set<Int>, longRunDay: Int?) {
            self.availableDays = availableDays.isEmpty ? Set(1...7) : availableDays
            self.longRunDay = longRunDay
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case dayToggled(Int)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .dayToggled(day):
                if state.availableDays.contains(day) {
                    // Floor: never let the runner drop below 1 training day.
                    guard state.availableDays.count > 1 else { return .none }
                    state.availableDays.remove(day)
                    if state.longRunDay == day { state.longRunDay = nil }
                } else {
                    state.availableDays.insert(day)
                }
                return .none
            }
        }
    }
}
