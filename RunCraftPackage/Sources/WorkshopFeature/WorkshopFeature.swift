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
                let isYours: Bool
                if case .detail(let detailState) = state.path.last {
                    isYours = detailState.source == .yours
                } else {
                    isYours = false
                }
                state.path.append(.editor(
                    WorkoutEditor.State(loading: template, asCopy: !isYours)
                ))
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
}
