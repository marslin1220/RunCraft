import ComposableArchitecture
import Foundation
import HealthKitClient
import RunCraftModels
import VDOTEngine

@Reducer public struct TrainingPlan {
    @ObservableState public struct State {
        public var hasGoal: Bool = false
        public var paceZones: PaceZones? = nil
        public var isLoadingVDOT: Bool = false
        @Presents public var destination: Destination.State? = nil

        public init() {}
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
        case destination(PresentationAction<Destination.Action>)
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

            case .destination(.dismiss):
                // Destination closed (e.g. SetupRaceGoal sheet dismissed after Save).
                // Re-check goal/VDOT state so paceZones refresh immediately.
                return .send(.onAppear)

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

public enum PlanError: Error {
    case noGoalFound
}
