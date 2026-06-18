import AppleWatchSync
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
        #if os(iOS)
        public var liveWorkout: LiveWorkoutDisplay? = nil
        #endif

        public init() {}
    }

    #if os(iOS)
    public struct LiveWorkoutDisplay: Equatable {
        public var message: WorkoutMirrorMessage

        public init() {
            message = WorkoutMirrorMessage(
                stepName: "", stepGoalText: "", stepProgress: 0,
                heartRate: 0, paceSecPerKm: 0, totalMetres: 0,
                elapsedSeconds: 0, isPaused: false
            )
        }
    }
    #endif

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
        #if os(iOS)
        case onTask
        case liveWorkoutEvent(LiveWorkoutEvent)
        case pauseWorkoutTapped
        case resumeWorkoutTapped
        case endWorkoutTapped
        #endif
    }

    public init() {}

    #if os(iOS)
    @Dependency(\.liveWorkoutClient) var liveWorkoutClient
    @Dependency(\.liveActivityClient) var liveActivityClient
    #endif

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
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            #if os(iOS)
            case .onTask:
                let client = liveWorkoutClient
                return .run { send in
                    for await event in client.events() {
                        await send(.liveWorkoutEvent(event))
                    }
                }

            case .liveWorkoutEvent(let event):
                switch event {
                case .sessionStarted:
                    state.liveWorkout = LiveWorkoutDisplay()
                    return .none

                case .messageReceived(let msg):
                    let isFirstMessage = state.liveWorkout?.message.stepName.isEmpty == true
                    state.liveWorkout?.message = msg
                    let client = liveActivityClient
                    return .run { _ in
                        if isFirstMessage {
                            await client.startSession(msg.stepName, msg)
                        } else {
                            await client.updateSession(msg)
                        }
                    }

                case .sessionPaused:
                    state.liveWorkout?.message.isPaused = true
                    guard let msg = state.liveWorkout?.message else { return .none }
                    let clientP = liveActivityClient
                    return .run { _ in await clientP.updateSession(msg) }

                case .sessionResumed:
                    state.liveWorkout?.message.isPaused = false
                    guard let msg = state.liveWorkout?.message else { return .none }
                    let clientR = liveActivityClient
                    return .run { _ in await clientR.updateSession(msg) }

                case .sessionEnded:
                    state.liveWorkout = nil
                    let clientE = liveActivityClient
                    return .run { _ in await clientE.endSession() }
                }

            case .pauseWorkoutTapped:
                let client = liveWorkoutClient
                return .run { _ in
                    await client.sendCommand(WorkoutMirrorCommand(kind: .pause))
                }

            case .resumeWorkoutTapped:
                let client = liveWorkoutClient
                return .run { _ in
                    await client.sendCommand(WorkoutMirrorCommand(kind: .resume))
                }

            case .endWorkoutTapped:
                let client = liveWorkoutClient
                return .run { _ in
                    await client.sendCommand(WorkoutMirrorCommand(kind: .end))
                }
            #endif

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
