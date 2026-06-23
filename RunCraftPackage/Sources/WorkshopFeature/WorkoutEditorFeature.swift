import AppleWatchSync
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import RunCraftModels

@Reducer public struct WorkoutEditor {
    @ObservableState public struct State: Equatable {
        /// nil = unsaved new template; non-nil = editing existing template from DB.
        public var editingTemplateId: UUID? = nil
        public var templateName: String = "New Workout"
        public var blocks: IdentifiedArrayOf<WorkoutBlock> = []
        public var source: Source = .yours
        /// For `source == .planSession`: whether this is the session
        /// scheduled for *today* in the *current* training week. HealthKit
        /// sync-back matches a completed workout to today's session by
        /// date, not by which session card was opened — starting a
        /// different (past/future) session from here would get its
        /// completion misattributed. Always `true` for `.yours`/`.template`.
        public var isTodaySession: Bool = true
        /// The original planned session when `source == .planSession`. Used
        /// to populate the "Change Session Type" toolbar menu with curated
        /// alternatives and to carry the session identity through the
        /// swap delegate.
        public var planSession: PlannedSession? = nil
        public var watchAvailable: Bool = true
        public var saveStatus: SaveStatus = .idle
        public var syncStatus: SyncStatus = .idle
        /// Id of a block that was just appended optimistically and is being
        /// configured in the edit sheet. If the user cancels that sheet, we
        /// drop the block so they don't get a default-value Step or empty
        /// Repeat sitting in the workout.
        public var pendingBlockId: WorkoutBlock.ID? = nil
        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public enum Source: Equatable {
            case yours          // existing user-owned template; Save updates in place
            case template       // built-in preset; Save creates a Yours copy
            case planSession    // generated session; Save creates a Yours copy
        }

        public enum SaveStatus: Equatable {
            case idle
            case saving
            case saved
            case failed(String)
        }

        public enum SyncStatus: Equatable {
            case idle
            case sending
            case sent
            case failed(String)
        }

        public init() {}

        public init(templateName: String = "New Workout", blocks: [WorkoutBlock]) {
            self.templateName = templateName
            self.blocks = IdentifiedArray(uniqueElements: blocks)
        }

        /// Load an existing template for editing. `asCopy=true` clears
        /// editingTemplateId so the first Save creates a new record.
        public init(
            loading template: WorkoutTemplate,
            asCopy: Bool,
            source: Source = .yours,
            isTodaySession: Bool = true,
            planSession: PlannedSession? = nil
        ) {
            self.editingTemplateId = asCopy ? nil : template.id
            self.templateName = template.name
            self.blocks = IdentifiedArray(uniqueElements: template.blocks)
            self.source = source
            self.isTodaySession = isTodaySession
            self.planSession = planSession
        }

        /// Whether "Start Workout" should be offered. Requires a paired Watch
        /// and either a non-plan-session source or today's actual session.
        public var canStartOnWatch: Bool {
            watchAvailable && (source != .planSession || isTodaySession)
        }

        /// Top-level steps in the workout (used by EditRepeatGroup to offer
        /// "include from workout" checkboxes).
        public var topLevelSteps: [WorkoutStep] {
            blocks.compactMap { block in
                if case let .step(s) = block { return s }
                return nil
            }
        }

        /// Total estimated workout distance in metres (counts repeat group iterations).
        public var totalMetres: Double {
            blocks.reduce(0) { acc, block in
                switch block {
                case .step(let s):
                    if case .distance(let m) = s.goal { return acc + m }
                    return acc
                case .repeatGroup(let g):
                    let perRound = g.steps.reduce(0.0) { sub, s in
                        if case .distance(let m) = s.goal { return sub + m }
                        return sub
                    }
                    return acc + perRound * Double(g.iterations)
                }
            }
        }
    }

    @Reducer public enum Destination {
        case editStep(EditStep)
        case editRepeatGroup(EditRepeatGroup)
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case addStepTapped(StepKind)
        case addRepeatGroupTapped
        case blockTapped(id: WorkoutBlock.ID)
        case deleteBlock(id: WorkoutBlock.ID)
        case moveBlocks(IndexSet, Int)

        // Persistence
        case saveTapped
        case saveResponse(Result<UUID, any Error>)
        case newTemplateTapped
        case deleteTemplate(WorkoutTemplate.ID)

        // Lifecycle
        case onTask

        // Apple Watch handoff
        case startTapped
        case syncResponse(Result<Void, any Error>)
        /// Clears the brief "Sent" confirmation back to idle — debounces
        /// the button so an accidental second tap doesn't immediately
        /// re-schedule the workout.
        case syncStatusReset

        // Duplicate — emits delegate; Workshop reducer does the DB insert
        case duplicateTapped

        // Session substitution — only available when source == .planSession
        case swapSession(SessionType, variantNote: String?)

        case alert(PresentationAction<Alert>)
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)

        public enum Alert: Equatable {}
        public enum Delegate: Equatable {
            /// Carry the editor's current state up so Workshop can write a
            /// "Yours" copy without re-deriving anything.
            case requestDuplicate(WorkoutTemplate)
            /// Substitute the planned session's type. Parent handles the DB write.
            case swapSession(PlannedSession, to: SessionType, variantNote: String?)
        }
    }

    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now
    @Dependency(\.continuousClock) var clock
    @Dependency(\.workoutTemplateRepository) var repository
    @Dependency(\.watchConnectivityClient) var watchConnectivityClient
    @Dependency(\.hkWatchTriggerClient) var hkWatchTriggerClient

    /// How long the "Sent" confirmation stays up before the button reverts
    /// to "Start Workout" — long enough to read, short enough that a
    /// genuine re-send isn't blocked for long.
    static let sentConfirmationDuration: Duration = .seconds(3)

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onTask:
                state.watchAvailable = watchConnectivityClient.isWatchPaired()
                return .none

            case .binding:
                return .none

            case let .addStepTapped(kind):
                let step = WorkoutStep(id: uuid(), kind: kind, goal: defaultGoal(for: kind))
                state.blocks.append(.step(step))
                state.pendingBlockId = step.id
                state.destination = .editStep(EditStep.State(step: step))
                return .none

            case .addRepeatGroupTapped:
                let group = RepeatGroup(id: uuid(), iterations: 4, steps: [])
                state.blocks.append(.repeatGroup(group))
                state.pendingBlockId = group.id
                state.destination = .editRepeatGroup(EditRepeatGroup.State(
                    group: group,
                    availableSteps: state.topLevelSteps
                ))
                return .none

            case let .blockTapped(id):
                guard let block = state.blocks[id: id] else { return .none }
                // Editing an existing block — clear any stale pending flag.
                state.pendingBlockId = nil
                switch block {
                case .step(let step):
                    state.destination = .editStep(EditStep.State(step: step))
                case .repeatGroup(let group):
                    state.destination = .editRepeatGroup(EditRepeatGroup.State(
                        group: group,
                        availableSteps: state.topLevelSteps
                    ))
                }
                return .none

            case let .deleteBlock(id):
                state.blocks.remove(id: id)
                return .none

            case let .moveBlocks(source, destination):
                state.blocks.move(fromOffsets: source, toOffset: destination)
                return .none

            case .saveTapped:
                guard !state.blocks.isEmpty else { return .none }
                let id = state.editingTemplateId ?? uuid()
                let template = WorkoutTemplate(
                    id: id,
                    name: state.templateName.isEmpty ? "Untitled" : state.templateName,
                    blocks: Array(state.blocks),
                    createdAt: now,
                    updatedAt: now
                )
                state.saveStatus = .saving
                return .run { [repository, template] send in
                    await send(.saveResponse(Result {
                        try await repository.save(template)
                    }))
                }

            case let .saveResponse(.success(id)):
                state.editingTemplateId = id
                state.source = .yours
                state.saveStatus = .saved
                return .none

            case let .saveResponse(.failure(error)):
                state.saveStatus = .failed(error.localizedDescription)
                return .none

            case .newTemplateTapped:
                state.editingTemplateId = nil
                state.templateName = "New Workout"
                state.blocks.removeAll()
                state.saveStatus = .idle
                state.source = .yours
                return .none

            case let .deleteTemplate(id):
                return .run { [repository] _ in
                    try await repository.delete(id)
                }

            case .startTapped:
                guard !state.blocks.isEmpty, state.canStartOnWatch else { return .none }
                state.syncStatus = .sending
                let template = WorkoutTemplate(
                    id: state.editingTemplateId ?? uuid(),
                    name: state.templateName.isEmpty ? "Untitled" : state.templateName,
                    blocks: Array(state.blocks),
                    createdAt: now,
                    updatedAt: now
                )
                return .run { [hkWatchTriggerClient] send in
                    await send(.syncResponse(Result {
                        try await hkWatchTriggerClient.startWatchSession(
                            WatchWorkoutPayload(name: template.name, blocks: template.blocks)
                        )
                    }))
                }

            case .syncResponse(.success):
                state.syncStatus = .sent
                return .run { [clock] send in
                    try await clock.sleep(for: Self.sentConfirmationDuration)
                    await send(.syncStatusReset)
                }

            case .syncStatusReset:
                if state.syncStatus == .sent {
                    state.syncStatus = .idle
                }
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

            case .duplicateTapped:
                let template = WorkoutTemplate(
                    id: uuid(),
                    name: state.templateName + " copy",
                    blocks: Array(state.blocks),
                    createdAt: now,
                    updatedAt: now
                )
                return .send(.delegate(.requestDuplicate(template)))

            case let .swapSession(newType, variantNote):
                guard let session = state.planSession else { return .none }
                return .send(.delegate(.swapSession(session, to: newType, variantNote: variantNote)))

            case let .destination(.presented(.editStep(.delegate(.saved(step))))):
                state.blocks[id: step.id] = .step(step)
                state.pendingBlockId = nil
                state.destination = nil
                return .none

            case let .destination(.presented(.editRepeatGroup(.delegate(.saved(group))))):
                state.blocks[id: group.id] = .repeatGroup(group)
                state.pendingBlockId = nil
                state.destination = nil
                return .none

            case .destination(.dismiss):
                // Sheet closed (user tapped Cancel or swiped down). If a
                // newly-appended block hadn't been saved yet, drop it so the
                // workout doesn't keep a default-value Step or empty Repeat.
                if let pendingId = state.pendingBlockId {
                    state.blocks.remove(id: pendingId)
                    state.pendingBlockId = nil
                }
                return .none

            case .destination, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    private func defaultGoal(for kind: StepKind) -> StepGoal {
        switch kind {
        case .warmup, .cooldown: .time(seconds: 10 * 60)
        case .work:              .distance(metres: 1_000)
        case .recovery:          .time(seconds: 60)
        }
    }
}

extension WorkoutEditor.Destination.State: Equatable {}

// MARK: - EditStep

@Reducer public struct EditStep {
    @ObservableState public struct State: Equatable {
        public var step: WorkoutStep
        public var goalUnit: GoalUnit
        public var distanceMetres: Double
        public var minutes: Int
        public var seconds: Int
        public var alertKind: AlertKind
        public var paceMinSec: Int   // sec/km (combined min:sec)
        public var paceMaxSec: Int
        public var hrMin: Int
        public var hrMax: Int

        public enum GoalUnit: String, CaseIterable, Equatable {
            case distance
            case time
            case openEnded
            var label: String {
                switch self {
                case .distance:  "Distance"
                case .time:      "Time"
                case .openEnded: "Open"
                }
            }
        }

        public enum AlertKind: String, CaseIterable, Equatable {
            case none
            case pace
            case heartRate
            var label: String {
                switch self {
                case .none:       "None"
                case .pace:       "Pace"
                case .heartRate:  "Heart rate"
                }
            }
        }

        public init(step: WorkoutStep) {
            self.step = step
            switch step.goal {
            case .openEnded:
                self.goalUnit = .openEnded
                self.distanceMetres = 1_000
                self.minutes = 5
                self.seconds = 0
            case .distance(let m):
                self.goalUnit = .distance
                self.distanceMetres = m
                self.minutes = 5
                self.seconds = 0
            case .time(let s):
                self.goalUnit = .time
                self.distanceMetres = 1_000
                self.minutes = s / 60
                self.seconds = s % 60
            }
            switch step.alert {
            case .none:
                self.alertKind = .none
                self.paceMinSec = 360
                self.paceMaxSec = 420
                self.hrMin = 130
                self.hrMax = 160
            case let .paceRange(lo, hi):
                self.alertKind = .pace
                self.paceMinSec = lo
                self.paceMaxSec = hi
                self.hrMin = 130
                self.hrMax = 160
            case let .heartRate(lo, hi):
                self.alertKind = .heartRate
                self.paceMinSec = 360
                self.paceMaxSec = 420
                self.hrMin = lo
                self.hrMax = hi
            }
        }

        public var isValid: Bool {
            let goalOK: Bool = switch goalUnit {
            case .openEnded: true
            case .distance:  distanceMetres > 0
            case .time:      minutes * 60 + seconds > 0
            }
            let alertOK: Bool = switch alertKind {
            case .none:      true
            case .pace:      paceMinSec > 0 && paceMaxSec >= paceMinSec
            case .heartRate: hrMin > 0 && hrMax >= hrMin
            }
            return goalOK && alertOK
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            /// Carries the final step value so the parent doesn't have to
            /// reach into `state.destination` to read it back.
            case saved(WorkoutStep)
        }
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                switch state.goalUnit {
                case .openEnded:
                    state.step.goal = .openEnded
                case .distance:
                    state.step.goal = .distance(metres: state.distanceMetres)
                case .time:
                    state.step.goal = .time(seconds: state.minutes * 60 + state.seconds)
                }
                switch state.alertKind {
                case .none:
                    state.step.alert = nil
                case .pace:
                    state.step.alert = .paceRange(
                        minSecPerKm: state.paceMinSec,
                        maxSecPerKm: state.paceMaxSec
                    )
                case .heartRate:
                    state.step.alert = .heartRate(min: state.hrMin, max: state.hrMax)
                }
                return .none

            case .saveTapped:
                return .send(.delegate(.saved(state.step)))

            case .delegate:
                return .none

            case .cancelTapped:
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }
}

// MARK: - EditRepeatGroup

@Reducer public struct EditRepeatGroup {
    @ObservableState public struct State: Equatable {
        public var group: RepeatGroup
        /// Top-level steps from the parent workout — offered as checkboxes
        /// so the user can pull copies into the repeat without retyping.
        public var availableSteps: [WorkoutStep] = []
        /// Same idea as WorkoutEditor.pendingBlockId: id of a step we just
        /// appended optimistically. Dropped on cancel so the user doesn't
        /// end up with a stray 400 m default if they back out of the sheet.
        public var pendingStepId: WorkoutStep.ID? = nil
        @Presents public var editingStep: EditStep.State?

        public init(group: RepeatGroup, availableSteps: [WorkoutStep] = []) {
            self.group = group
            self.availableSteps = availableSteps
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
        case toggleAvailableStep(WorkoutStep)
        case addStepTapped
        case editStepTapped(WorkoutStep.ID)
        case deleteStep(id: WorkoutStep.ID)
        case editingStep(PresentationAction<EditStep.Action>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case saved(RepeatGroup)
        }
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .toggleAvailableStep(step):
                // We track inclusion by source step.id stored on a derived
                // step in the group. Adding makes an independent copy with a
                // fresh id so future edits stay isolated.
                if let existing = state.group.steps.first(where: { isCopyOf($0, source: step) }) {
                    state.group.steps.removeAll { $0.id == existing.id }
                } else {
                    let copy = WorkoutStep(
                        id: uuid(),
                        kind: step.kind,
                        goal: step.goal,
                        alert: step.alert
                    )
                    state.group.steps.append(copy)
                }
                return .none

            case .addStepTapped:
                let step = WorkoutStep(id: uuid(), kind: .work, goal: .distance(metres: 400))
                state.group.steps.append(step)
                state.pendingStepId = step.id
                state.editingStep = EditStep.State(step: step)
                return .none

            case let .editStepTapped(id):
                guard let step = state.group.steps.first(where: { $0.id == id }) else { return .none }
                state.pendingStepId = nil
                state.editingStep = EditStep.State(step: step)
                return .none

            case let .deleteStep(id):
                state.group.steps.removeAll { $0.id == id }
                return .none

            case let .editingStep(.presented(.delegate(.saved(step)))):
                if let idx = state.group.steps.firstIndex(where: { $0.id == step.id }) {
                    state.group.steps[idx] = step
                }
                state.pendingStepId = nil
                state.editingStep = nil
                return .none

            case .editingStep(.dismiss):
                // Cancelled / swiped down — drop the half-configured step
                // if one was being added.
                if let pendingId = state.pendingStepId {
                    state.group.steps.removeAll { $0.id == pendingId }
                    state.pendingStepId = nil
                }
                return .none

            case .editingStep:
                return .none

            case .saveTapped:
                return .send(.delegate(.saved(state.group)))

            case .delegate:
                return .none

            case .cancelTapped:
                return .run { [dismiss] _ in await dismiss() }
            }
        }
        .ifLet(\.$editingStep, action: \.editingStep) {
            EditStep()
        }
    }

    /// Two steps are "the same source" if they share kind + goal + alert.
    /// Identity (UUID) intentionally not checked — the in-repeat copy has
    /// its own id, but if the user hasn't customised it yet the content
    /// matches the source.
    private func isCopyOf(_ a: WorkoutStep, source b: WorkoutStep) -> Bool {
        a.kind == b.kind && a.goal == b.goal && a.alert == b.alert
    }
}
