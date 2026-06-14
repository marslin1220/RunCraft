import ComposableArchitecture
import Foundation
import RunCraftModels
import SQLiteData
import VDOTEngine

/// "Set Up VDOT" — for a runner with no race goal who still wants a
/// training plan. Creates a placeholder `RaceGoal` ("Base Training") with
/// a single rolling week, so the Plan tab has something actionable without
/// requiring a race to count down to.
@Reducer public struct SetupVDOT {
    @ObservableState public struct State: Equatable {
        public var vdotInput: VDOTInput.State = .init()

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case vdotInput(VDOTInput.Action)
        case saveButtonTapped
        case cancelButtonTapped
    }

    @Dependency(\.defaultDatabase) var database
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Scope(state: \.vdotInput, action: \.vdotInput) {
            VDOTInput()
        }
        Reduce { state, action in
            switch action {
            case .binding, .vdotInput:
                return .none

            case .saveButtonTapped:
                guard let vdot = state.vdotInput.effectiveVDOT else { return .none }
                let goal = RaceGoal(
                    name: "Base Training",
                    targetDate: now,
                    distanceKm: 0,
                    currentVDOT: vdot,
                    createdAt: now,
                    isPlaceholder: true
                )
                let (week, sessions) = TrainingPlanGenerator.rollingWeek(raceGoalId: goal.id, vdot: vdot)
                let snapshot = VDOTSnapshot(vdot: vdot, recordedAt: now, source: .initial)
                return .run { [database, dismiss] _ in
                    try await database.write { db in
                        try RaceGoal.upsert { goal }.execute(db)
                        try TrainingWeek.upsert { week }.execute(db)
                        for session in sessions {
                            try PlannedSession.upsert { session }.execute(db)
                        }
                        try VDOTSnapshot.upsert { snapshot }.execute(db)
                    }
                    await dismiss()
                }

            case .cancelButtonTapped:
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }
}
