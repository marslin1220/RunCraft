import ComposableArchitecture
import TrainingPlanFeature
import WorkshopFeature

@Reducer public struct AppFeature {
    @ObservableState public struct State {
        public var selectedTab: Tab = .plan
        public var plan: TrainingPlan.State = .init()
        public var workshop: Workshop.State = .init()
        public var settings: Settings.State = .init()

        public init() {}
    }

    public enum Tab: String, Equatable, CaseIterable {
        case plan
        case workshop
        case insights
        case settings
    }

    public enum Action {
        case tabSelected(Tab)
        case plan(TrainingPlan.Action)
        case workshop(Workshop.Action)
        case settings(Settings.Action)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.plan, action: \.plan) {
            TrainingPlan()
        }
        Scope(state: \.workshop, action: \.workshop) {
            Workshop()
        }
        Scope(state: \.settings, action: \.settings) {
            Settings()
        }
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
            case .plan, .workshop, .settings:
                return .none
            }
        }
    }
}
