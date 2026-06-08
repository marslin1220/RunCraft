import ComposableArchitecture
import Foundation
import RunCraftModels

/// Top-level Workshop shell.
///
/// Three-segment list (Yours / Templates / Plan) → tap a workout to push
/// a read-only `WorkoutDetail` page → tap Edit to push `WorkoutEditor`.
/// `+ New workout` pushes a blank editor directly.
@Reducer public struct Workshop {
    @ObservableState public struct State {
        public var selectedSegment: Segment = .yours
        public var path = StackState<Path.State>()

        public init() {}
    }

    public enum Segment: String, CaseIterable, Equatable {
        case yours
        case templates
        case plan

        public var label: String {
            switch self {
            case .yours:     "Yours"
            case .templates: "Templates"
            case .plan:      "Plan"
            }
        }
    }

    @Reducer public enum Path {
        case detail(WorkoutDetail)
        case editor(WorkoutEditor)
    }

    public enum Action {
        case segmentSelected(Segment)
        case newWorkoutTapped
        case workoutTapped(WorkoutTemplate, WorkoutDetail.Source)
        case browseTemplatesTapped
        case openDetail(WorkoutTemplate, WorkoutDetail.Source)
        case path(StackActionOf<Path>)
    }

    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now
    @Dependency(\.workoutTemplateRepository) var repository

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .segmentSelected(seg):
                state.selectedSegment = seg
                return .none

            case .newWorkoutTapped:
                state.path.append(.editor(WorkoutEditor.State()))
                return .none

            case let .workoutTapped(template, source):
                state.path.append(.detail(WorkoutDetail.State(workout: template, source: source)))
                return .none

            case .browseTemplatesTapped:
                state.selectedSegment = .templates
                return .none

            case let .openDetail(template, source):
                // Called by AppFeature when Plan tab requests cross-tab navigation.
                state.path.removeAll()
                state.path.append(.detail(WorkoutDetail.State(workout: template, source: source)))
                return .none

            // Detail → request Edit: push editor; asCopy=true unless it's "yours"
            case let .path(.element(_, .detail(.delegate(.requestEdit(template))))):
                state.path.append(.editor(
                    WorkoutEditor.State(
                        loading: template,
                        asCopy: !isCurrentDetailYours(state: state)
                    )
                ))
                return .none

            // Detail → request edit of a specific block: push editor with that
            // block's edit sheet preselected.
            case let .path(.element(_, .detail(.delegate(.requestEditBlock(template, blockId))))):
                var editorState = WorkoutEditor.State(
                    loading: template,
                    asCopy: !isCurrentDetailYours(state: state)
                )
                if let block = editorState.blocks[id: blockId] {
                    switch block {
                    case let .step(step):
                        editorState.destination = .editStep(EditStep.State(step: step))
                    case let .repeatGroup(group):
                        editorState.destination = .editRepeatGroup(EditRepeatGroup.State(group: group))
                    }
                }
                state.path.append(.editor(editorState))
                return .none

            // Detail → request Duplicate: insert copy into DB and switch to Yours
            case let .path(.element(_, .detail(.delegate(.requestDuplicate(template))))):
                let copy = WorkoutTemplate(
                    id: uuid(),
                    name: template.name + " copy",
                    blocks: template.blocks,
                    createdAt: now,
                    updatedAt: now
                )
                state.selectedSegment = .yours
                // Pop back to the list so the new copy is visible.
                state.path.removeAll()
                return .run { [repository, copy] _ in
                    _ = try await repository.save(copy)
                }

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }

    /// True iff the top of the path is a detail page whose source is `.yours`.
    private func isCurrentDetailYours(state: State) -> Bool {
        if case let .detail(detailState) = state.path.last {
            return detailState.source == .yours
        }
        return false
    }
}
