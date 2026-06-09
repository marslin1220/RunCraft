import ComposableArchitecture
import Foundation
import RunCraftModels

/// Top-level Workouts shell.
///
/// Two-segment library (Yours / Templates). Tapping any workout pushes a
/// single `WorkoutEditor` screen — read-only/edit is no longer split: the
/// editor is always live, and its `Source` field controls whether Save
/// updates the existing row (`yours`) or creates a copy (`template`).
/// `+ New workout` pushes a blank editor.
///
/// Note: there used to be a third "Plan" segment that surfaced today's
/// planned session, but it duplicated the Plan tab's session card and
/// went stale before the 16-week training window opened. Removed.
@Reducer public struct Workshop {
    @ObservableState public struct State {
        public var selectedSegment: Segment = .yours
        public var path = StackState<Path.State>()

        public init() {}
    }

    public enum Segment: String, CaseIterable, Equatable {
        case yours
        case templates

        public var label: String {
            switch self {
            case .yours:     "Yours"
            case .templates: "Templates"
            }
        }
    }

    @Reducer public enum Path {
        case editor(WorkoutEditor)
    }

    public enum Action {
        case segmentSelected(Segment)
        case newWorkoutTapped
        case workoutTapped(WorkoutTemplate, WorkoutEditor.State.Source)
        case browseTemplatesTapped
        case openDetail(WorkoutTemplate, WorkoutEditor.State.Source)
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
                let asCopy = source != .yours
                state.path.append(.editor(
                    WorkoutEditor.State(
                        loading: template,
                        asCopy: asCopy,
                        source: source
                    )
                ))
                return .none

            case .browseTemplatesTapped:
                state.selectedSegment = .templates
                return .none

            case let .openDetail(template, source):
                // Called by AppFeature when Plan tab requests cross-tab navigation.
                let asCopy = source != .yours
                state.path.removeAll()
                state.path.append(.editor(
                    WorkoutEditor.State(
                        loading: template,
                        asCopy: asCopy,
                        source: source
                    )
                ))
                return .none

            // Editor → Duplicate: persist the carried template to the Yours
            // table. Doesn't navigate — user keeps editing what they had open.
            case let .path(.element(_, .editor(.delegate(.requestDuplicate(template))))):
                return .run { [repository, template] _ in
                    _ = try await repository.save(template)
                }

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
