import ComposableArchitecture
import Foundation
import RunCraftModels
import SQLiteData

/// Lets the runner change their preferred training days / long-run day
/// mid-plan. Unlike `AdjustVDOT` (paces are computed live from VDOT),
/// session placement is baked into stored `PlannedSession` rows, so saving
/// triggers `TrainingPlanRegeneration` for weeks that haven't started yet.
@Reducer public struct AdjustTrainingDays {
    @ObservableState public struct State: Equatable {
        public var raceGoalId: RaceGoal.ID
        public var trainingDaysInput: TrainingDaysInput.State
        public let originalAvailableDays: Set<Int>
        public let originalLongRunDay: Int?
        public let currentVDOT: Double
        public let isPlaceholder: Bool

        public init(goal: RaceGoal) {
            self.raceGoalId = goal.id
            self.trainingDaysInput = TrainingDaysInput.State(availableDays: goal.availableDays, longRunDay: goal.longRunDay)
            self.originalAvailableDays = goal.availableDays
            self.originalLongRunDay = goal.longRunDay
            self.currentVDOT = goal.currentVDOT
            self.isPlaceholder = goal.isPlaceholder
        }

        public var hasChanged: Bool {
            trainingDaysInput.availableDays != originalAvailableDays
                || trainingDaysInput.longRunDay != originalLongRunDay
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case trainingDaysInput(TrainingDaysInput.Action)
        case saveTapped
        case cancelTapped
    }

    @Dependency(\.defaultDatabase) var database
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Scope(state: \.trainingDaysInput, action: \.trainingDaysInput) {
            TrainingDaysInput()
        }
        Reduce { state, action in
            switch action {
            case .binding, .trainingDaysInput:
                return .none

            case .saveTapped:
                guard state.hasChanged else {
                    return .run { [dismiss] _ in await dismiss() }
                }
                let goalId = state.raceGoalId
                let availableDays = state.trainingDaysInput.availableDays
                let longRunDay = state.trainingDaysInput.longRunDay
                let vdot = state.currentVDOT
                return .run { [database, dismiss, now] _ in
                    try await database.write { db in
                        guard var goal = try RaceGoal.where({ $0.id.eq(goalId) }).fetchOne(db) else { return }
                        goal.availableDays = availableDays
                        goal.longRunDay = longRunDay
                        try RaceGoal.upsert { goal }.execute(db)
                        try TrainingPlanRegeneration.regenerateFutureWeeks(goal: goal, vdot: vdot, now: now, db: db)
                    }
                    await dismiss()
                }

            case .cancelTapped:
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }
}
