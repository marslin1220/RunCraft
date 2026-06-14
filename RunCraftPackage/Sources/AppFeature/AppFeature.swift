import ComposableArchitecture
import InsightsFeature
import TrainingPlanFeature
import WorkshopFeature

@Reducer public struct AppFeature {
    @ObservableState public struct State {
        public var selectedTab: Tab = .plan
        public var plan: TrainingPlan.State = .init()
        public var workouts: Workshop.State = .init()
        public var insights: InsightsFeature.State = .init()
        public var settings: Settings.State = .init()

        public init() {}
    }

    public enum Tab: String, Equatable, CaseIterable {
        case plan
        case workouts
        case insights
        case settings
    }

    public enum Action {
        case tabSelected(Tab)
        case plan(TrainingPlan.Action)
        case workouts(Workshop.Action)
        case insights(InsightsFeature.Action)
        case settings(Settings.Action)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.plan, action: \.plan) {
            TrainingPlan()
        }
        Scope(state: \.workouts, action: \.workouts) {
            Workshop()
        }
        Scope(state: \.insights, action: \.insights) {
            InsightsFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            Settings()
        }
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case let .plan(.delegate(.openWorkoutInWorkshop(template, source, isTodaySession))):
                state.selectedTab = .workouts
                let workoutsSource: WorkoutEditor.State.Source = switch source {
                case .planSession: .planSession
                case .template:    .template
                }
                return .send(.workouts(.openDetail(template, workoutsSource, isTodaySession: isTodaySession)))

            case .insights(.delegate(.setUpVDOTTapped)):
                state.selectedTab = .plan
                return .send(.plan(.setupVDOTButtonTapped))

            case .plan, .workouts, .insights, .settings:
                return .none
            }
        }
    }
}
