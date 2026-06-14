import ComposableArchitecture
import Foundation
import RunCraftModels
import VDOTEngine

@Reducer public struct SetupRaceGoal {
    @ObservableState public struct State: Equatable {
        public var goalName: String = ""
        public var targetDate: Date = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
        public var distanceKm: Double = 21.0

        /// nil = creating a new goal; non-nil = editing the existing goal
        /// in place. When set, Save reuses the same id (so weeks + sessions
        /// get cleanly regenerated rather than orphaning).
        public var editingId: UUID? = nil
        /// VDOT the goal was saved with last time — used to decide whether
        /// to write a fresh VDOTSnapshot on save.
        public var originalVDOT: Double? = nil

        public var vdotInput: VDOTInput.State = .init()

        public var paceZones: PaceZones? { vdotInput.paceZones }

        /// HealthKit-detected takes priority; falls back to calculated from manual race time.
        public var effectiveVDOT: Double? { vdotInput.effectiveVDOT }

        public var calculatedVDOT: Double? { vdotInput.calculatedVDOT }

        var canSave: Bool {
            !goalName.isEmpty && effectiveVDOT != nil
        }

        public init() {}

        /// Pre-fill from the runner's current race goal so editing keeps
        /// every field they've already committed to (name, date, distance)
        /// and only the race-time row drives a re-calc.
        public init(editing goal: RaceGoal) {
            self.goalName = goal.name
            self.targetDate = goal.targetDate
            self.distanceKm = goal.distanceKm
            self.editingId = goal.id
            self.originalVDOT = goal.currentVDOT
            self.vdotInput = VDOTInput.State(detectedVDOT: goal.currentVDOT)
        }

        /// Pre-fill from a placeholder ("Base Training") goal when the
        /// runner converts it into a real race goal. Carries the detected
        /// VDOT over but leaves name/date/distance for the runner to enter —
        /// the placeholder's own values (name="Base Training", distanceKm=0)
        /// aren't meaningful race-goal defaults.
        public init(convertingPlaceholder goal: RaceGoal) {
            self.editingId = goal.id
            self.originalVDOT = goal.currentVDOT
            self.vdotInput = VDOTInput.State(detectedVDOT: goal.currentVDOT)
        }
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
                guard let vdot = state.effectiveVDOT else { return .none }
                let goalId = state.editingId ?? UUID()
                let goal = RaceGoal(
                    id: goalId,
                    name: state.goalName,
                    targetDate: state.targetDate,
                    distanceKm: state.distanceKm,
                    currentVDOT: vdot,
                    createdAt: now,
                    isPlaceholder: false
                )
                let (weeks, sessions) = TrainingPlanGenerator.generate(goal: goal, vdot: vdot)
                let isEditing = state.editingId != nil
                // Only snapshot when VDOT changed: avoids piling identical
                // points on the trend line on every cosmetic edit.
                let snapshot: VDOTSnapshot? = state.originalVDOT == vdot
                    ? nil
                    : VDOTSnapshot(vdot: vdot, recordedAt: now, source: .initial)
                return .run { [database, dismiss] _ in
                    try await database.write { db in
                        if isEditing {
                            // Cascade removes plannedSessions for these weeks.
                            try TrainingWeek
                                .where { $0.raceGoalId.eq(goalId) }
                                .delete()
                                .execute(db)
                        }
                        try RaceGoal.upsert { goal }.execute(db)
                        for week in weeks {
                            try TrainingWeek.upsert { week }.execute(db)
                        }
                        for session in sessions {
                            try PlannedSession.upsert { session }.execute(db)
                        }
                        if let snapshot {
                            try VDOTSnapshot.upsert { snapshot }.execute(db)
                        }
                    }
                    await dismiss()
                }

            case .cancelButtonTapped:
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }
}
