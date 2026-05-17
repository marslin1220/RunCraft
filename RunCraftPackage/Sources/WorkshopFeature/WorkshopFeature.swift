import ComposableArchitecture
import Foundation
import IdentifiedCollections
import RunCraftModels
import SQLiteData

@Reducer public struct Workshop {
    @ObservableState public struct State {
        /// nil = unsaved new template; non-nil = editing existing template from DB.
        public var editingTemplateId: UUID? = nil
        public var templateName: String = "New Workout"
        public var blocks: IdentifiedArrayOf<WorkoutBlock> = []
        public var isEditing: Bool = false
        public var isShowingLibrary: Bool = false
        public var saveStatus: SaveStatus = .idle
        @Presents public var destination: Destination.State?

        public enum SaveStatus: Equatable {
            case idle
            case saving
            case saved
            case failed(String)
        }

        public init() {}

        public init(templateName: String = "New Workout", blocks: [WorkoutBlock]) {
            self.templateName = templateName
            self.blocks = IdentifiedArray(uniqueElements: blocks)
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
        case toggleEditing
        case clearAllTapped

        // Persistence
        case saveTapped
        case saveResponse(Result<UUID, any Error>)
        case newTemplateTapped
        case libraryButtonTapped
        case templateSelected(WorkoutTemplate)
        case presetSelected(WorkoutTemplate)
        case deleteTemplate(WorkoutTemplate.ID)

        case destination(PresentationAction<Destination.Action>)
    }

    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now
    @Dependency(\.defaultDatabase) var database

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .addStepTapped(kind):
                let step = WorkoutStep(id: uuid(), kind: kind, goal: defaultGoal(for: kind))
                state.blocks.append(.step(step))
                return .none

            case .addRepeatGroupTapped:
                let work = WorkoutStep(id: uuid(), kind: .work, goal: .distance(metres: 400))
                let recovery = WorkoutStep(id: uuid(), kind: .recovery, goal: .time(seconds: 90))
                let group = RepeatGroup(id: uuid(), iterations: 4, steps: [work, recovery])
                state.blocks.append(.repeatGroup(group))
                // Open edit sheet immediately so user can configure iterations/steps.
                state.destination = .editRepeatGroup(EditRepeatGroup.State(group: group))
                return .none

            case let .blockTapped(id):
                guard let block = state.blocks[id: id] else { return .none }
                switch block {
                case .step(let step):
                    state.destination = .editStep(EditStep.State(step: step))
                case .repeatGroup(let group):
                    state.destination = .editRepeatGroup(EditRepeatGroup.State(group: group))
                }
                return .none

            case let .deleteBlock(id):
                state.blocks.remove(id: id)
                return .none

            case let .moveBlocks(source, destination):
                state.blocks.move(fromOffsets: source, toOffset: destination)
                return .none

            case .toggleEditing:
                state.isEditing.toggle()
                return .none

            case .clearAllTapped:
                state.blocks.removeAll()
                return .none

            case .saveTapped:
                guard !state.blocks.isEmpty else { return .none }
                let id = state.editingTemplateId ?? uuid()
                let existing = state.editingTemplateId != nil
                let template = WorkoutTemplate(
                    id: id,
                    name: state.templateName.isEmpty ? "Untitled" : state.templateName,
                    blocks: Array(state.blocks),
                    createdAt: now,
                    updatedAt: now
                )
                state.saveStatus = .saving
                return .run { [database, template, existing] send in
                    await send(.saveResponse(Result {
                        try await database.write { db in
                            if existing {
                                try WorkoutTemplate
                                    .where { $0.id.eq(template.id) }
                                    .update {
                                        $0.name = template.name
                                        $0.blocksData = template.blocksData
                                        $0.updatedAt = template.updatedAt
                                    }
                                    .execute(db)
                            } else {
                                try WorkoutTemplate.insert { template }.execute(db)
                            }
                        }
                        return template.id
                    }))
                }

            case let .saveResponse(.success(id)):
                state.editingTemplateId = id
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
                return .none

            case .libraryButtonTapped:
                state.isShowingLibrary = true
                return .none

            case let .templateSelected(template):
                state.editingTemplateId = template.id
                state.templateName = template.name
                state.blocks = IdentifiedArray(uniqueElements: template.blocks)
                state.isShowingLibrary = false
                state.saveStatus = .idle
                return .none

            case let .presetSelected(preset):
                // Load preset blocks but treat as new — editingTemplateId stays nil
                // so the first Save creates a new user-owned record.
                state.editingTemplateId = nil
                state.templateName = preset.name
                state.blocks = IdentifiedArray(uniqueElements: preset.blocks)
                state.isShowingLibrary = false
                state.saveStatus = .idle
                return .none

            case let .deleteTemplate(id):
                return .run { [database] _ in
                    try await database.write { db in
                        try WorkoutTemplate
                            .where { $0.id.eq(id) }
                            .delete()
                            .execute(db)
                    }
                }

            case .destination(.presented(.editStep(.saveTapped))):
                if case let .editStep(editState) = state.destination {
                    state.blocks[id: editState.step.id] = .step(editState.step)
                }
                state.destination = nil
                return .none

            case .destination(.presented(.editRepeatGroup(.saveTapped))):
                if case let .editRepeatGroup(editState) = state.destination {
                    state.blocks[id: editState.group.id] = .repeatGroup(editState.group)
                }
                state.destination = nil
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    private func defaultGoal(for kind: StepKind) -> StepGoal {
        switch kind {
        case .warmup, .cooldown: .time(seconds: 10 * 60)
        case .work:              .distance(metres: 1_000)
        case .recovery:          .time(seconds: 60)
        }
    }
}

// MARK: - EditStep

@Reducer public struct EditStep {
    @ObservableState public struct State: Equatable {
        public var step: WorkoutStep
        public var goalUnit: GoalUnit
        public var distanceMetres: Double
        public var minutes: Int
        public var seconds: Int

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
        }

        public var isValid: Bool {
            switch goalUnit {
            case .openEnded: true
            case .distance: distanceMetres > 0
            case .time:     minutes * 60 + seconds > 0
            }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
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
                return .none

            case .saveTapped:
                return .none   // parent reducer consumes this and writes back

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

        public init(group: RepeatGroup) {
            self.group = group
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
        case addStepTapped(StepKind)
        case deleteStep(id: WorkoutStep.ID)
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

            case let .addStepTapped(kind):
                let step = WorkoutStep(
                    id: uuid(),
                    kind: kind,
                    goal: kind == .work ? .distance(metres: 400) : .time(seconds: 90)
                )
                state.group.steps.append(step)
                return .none

            case let .deleteStep(id):
                state.group.steps.removeAll { $0.id == id }
                return .none

            case .saveTapped:
                return .none

            case .cancelTapped:
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }
}
