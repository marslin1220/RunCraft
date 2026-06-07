import ComposableArchitecture
import Foundation
import HealthKitClient
import RunCraftModels
import VDOTEngine

@Reducer public struct TrainingPlan {
    @ObservableState public struct State {
        public var hasGoal: Bool = false
        public var currentVDOT: Double = 0
        public var paceZones: PaceZones? = nil
        public var isLoadingVDOT: Bool = false
        public var path = StackState<Path.State>()
        @Presents public var destination: Destination.State? = nil

        public init() {}
    }

    @Reducer public enum Path {
        case weekSchedule(WeekSchedule)
    }

    @Reducer public enum Destination {
        case setupRaceGoal(SetupRaceGoal)
        case deleteConfirm(AlertState<DeleteAlertAction>)
    }

    public enum DeleteAlertAction: Equatable {
        case confirmDelete
    }

    public enum Action {
        case onAppear
        case createGoalButtonTapped
        case checkRaceGoalResponse(Result<Bool, any Error>)
        case fetchVDOTTapped
        case vdotFetchResponse(Result<Double, any Error>)
        case deletePlanRequested
        case recalculateVDOTRequested
        case planDeleted
        case countdownTapped
        case paceChipTapped(PaceZoneName)
        case sessionTapped(PlannedSession)
        case path(StackActionOf<Path>)
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)

        public enum Delegate {
            /// Parent (AppFeature) should switch to Workshop tab and open this workout.
            case openWorkoutInWorkshop(WorkoutTemplate, source: TemplateSource)
        }

        public enum TemplateSource: Equatable {
            case planSession
            case template
        }
    }

    @Dependency(\.healthKitClient) var healthKitClient
    @Dependency(\.defaultDatabase) var database

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [database] send in
                    await send(.checkRaceGoalResponse(Result {
                        let count = try await database.read { db in
                            try RaceGoal.all.fetchCount(db)
                        }
                        return count > 0
                    }))
                }

            case .createGoalButtonTapped:
                state.destination = .setupRaceGoal(SetupRaceGoal.State())
                return .none

            case let .checkRaceGoalResponse(.success(hasGoal)):
                state.hasGoal = hasGoal
                if hasGoal {
                    return .send(.fetchVDOTTapped)
                }
                return .none

            case .checkRaceGoalResponse(.failure):
                state.hasGoal = false
                return .none

            case .fetchVDOTTapped:
                state.isLoadingVDOT = true
                return .run { [database] send in
                    await send(.vdotFetchResponse(Result {
                        let goal = try await database.read { db in
                            try RaceGoal.order { $0.createdAt.desc() }.fetchOne(db)
                        }
                        guard let goal else { throw PlanError.noGoalFound }
                        return goal.currentVDOT
                    }))
                }

            case let .vdotFetchResponse(.success(vdot)):
                state.isLoadingVDOT = false
                state.currentVDOT = vdot
                state.paceZones = VDOTCalculator.paceZones(vdot: vdot)
                return .none

            case .vdotFetchResponse(.failure):
                state.isLoadingVDOT = false
                return .none

            case .deletePlanRequested:
                state.destination = .deleteConfirm(AlertState {
                    TextState("Delete plan?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState("Delete")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This removes your race goal and all generated weekly sessions. Completed workouts are kept.")
                })
                return .none

            case .recalculateVDOTRequested:
                state.destination = .setupRaceGoal(SetupRaceGoal.State())
                return .none

            case .destination(.presented(.deleteConfirm(.confirmDelete))):
                return .run { [database] send in
                    try await database.write { db in
                        // FK cascades remove trainingWeeks and plannedSessions automatically
                        try RaceGoal.all.delete().execute(db)
                    }
                    await send(.planDeleted)
                }

            case .planDeleted:
                state.hasGoal = false
                state.paceZones = nil
                return .none

            case .countdownTapped:
                state.path.append(.weekSchedule(WeekSchedule.State()))
                return .none

            case let .paceChipTapped(zone):
                let template = makePaceFocusTemplate(zone: zone, vdot: state.currentVDOT)
                return .send(.delegate(.openWorkoutInWorkshop(template, source: .template)))

            case let .sessionTapped(session):
                let template = PlanSessionAdapter.makeTemplate(from: session, vdot: state.currentVDOT)
                return .send(.delegate(.openWorkoutInWorkshop(template, source: .planSession)))

            case let .path(.element(_, .weekSchedule(.delegate(.openSession(session))))):
                let template = PlanSessionAdapter.makeTemplate(from: session, vdot: state.currentVDOT)
                state.path.removeAll()
                return .send(.delegate(.openWorkoutInWorkshop(template, source: .planSession)))

            case .path:
                return .none

            case .delegate:
                return .none

            case .destination(.dismiss):
                // Destination closed (e.g. SetupRaceGoal sheet dismissed after Save).
                // Re-check goal/VDOT state so paceZones refresh immediately.
                return .send(.onAppear)

            case .destination:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$destination, action: \.destination)
    }

    /// Quick-action template: 30-minute run at the chosen pace zone.
    private func makePaceFocusTemplate(zone: PaceZoneName, vdot: Double) -> WorkoutTemplate {
        let step = WorkoutStep(
            kind: zone == .easy ? .work : .work,
            goal: .time(seconds: 30 * 60),
            alert: .paceZone(zone, vdot: vdot)
        )
        return WorkoutTemplate(
            name: "\(zone.displayName) Run · 30 min",
            blocks: [.step(step)]
        )
    }
}

// MARK: - Week schedule sub-feature

@Reducer public struct WeekSchedule {
    @ObservableState public struct State: Equatable {
        public init() {}
    }
    public enum Action {
        case sessionTapped(PlannedSession)
        case delegate(Delegate)
        public enum Delegate {
            case openSession(PlannedSession)
        }
    }
    public init() {}
    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case let .sessionTapped(s):
                return .send(.delegate(.openSession(s)))
            case .delegate:
                return .none
            }
        }
    }
}

public enum PlanError: Error {
    case noGoalFound
}
