import ComposableArchitecture
import RunCraftModels
import Testing
@testable import WorkshopFeature

@MainActor
@Suite("WorkoutDetail reducer")
struct WorkoutDetailTests {

    // MARK: - Start

    @Test("Start tap shows 'coming soon' alert")
    func startTapped_showsAlert() async {
        let store = TestStore(initialState: WorkoutDetail.State(
            workout: .sample,
            source: .yours
        )) {
            WorkoutDetail()
        }

        await store.send(.startTapped) {
            $0.alert = AlertState {
                TextState("Apple Watch sync coming soon")
            } message: {
                TextState("Pair your Apple Watch to sync this workout. Coming in the next update.")
            }
        }
    }

    // MARK: - Edit delegation

    @Test("Edit tap emits delegate.requestEdit with the current workout")
    func editTapped_emitsDelegate() async {
        let workout = WorkoutTemplate.sample
        let store = TestStore(initialState: WorkoutDetail.State(
            workout: workout,
            source: .template
        )) {
            WorkoutDetail()
        }

        await store.send(.editTapped)
        await store.receive(\.delegate.requestEdit)
    }

    // MARK: - Duplicate delegation

    @Test("Duplicate tap emits delegate.requestDuplicate with the current workout")
    func duplicateTapped_emitsDelegate() async {
        let workout = WorkoutTemplate.sample
        let store = TestStore(initialState: WorkoutDetail.State(
            workout: workout,
            source: .template
        )) {
            WorkoutDetail()
        }

        await store.send(.duplicateTapped)
        await store.receive(\.delegate.requestDuplicate)
    }
}

// MARK: - Fixtures

extension WorkoutTemplate {
    fileprivate static var sample: WorkoutTemplate {
        WorkoutTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000FF")!,
            name: "Sample",
            blocks: [
                .step(WorkoutStep(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    kind: .work,
                    goal: .time(seconds: 600)
                ))
            ]
        )
    }
}
