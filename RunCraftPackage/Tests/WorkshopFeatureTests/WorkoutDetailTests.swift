import ComposableArchitecture
import RunCraftModels
import Testing
@testable import WorkshopFeature

@MainActor
@Suite("WorkoutDetail reducer")
struct WorkoutDetailTests {

    // MARK: - Start

    @Test("Start tap pushes workout to Watch via WorkoutKit (testValue path)")
    func startTapped_sendsToWatch() async {
        let store = TestStore(initialState: WorkoutDetail.State(
            workout: .sample,
            source: .yours
        )) {
            WorkoutDetail()
        } withDependencies: {
            // testValue is no-op success
            $0.workoutKitClient = .testValue
        }

        await store.send(.startTapped) {
            $0.syncStatus = .sending
        }
        await store.receive(\.syncResponse.success) {
            $0.syncStatus = .sent
        }
    }

    @Test("Start tap with WorkoutKit failure shows alert and records error")
    func startTapped_failure() async {
        let store = TestStore(initialState: WorkoutDetail.State(
            workout: .sample,
            source: .yours
        )) {
            WorkoutDetail()
        } withDependencies: {
            $0.workoutKitClient = WorkoutKitClient(
                isAvailable: { true },
                requestAuthorization: { .authorized },
                openInWorkoutApp: { _ in throw WorkoutKitError.watchNotPaired }
            )
        }

        await store.send(.startTapped) {
            $0.syncStatus = .sending
        }
        await store.receive(\.syncResponse.failure) {
            $0.syncStatus = .failed("No paired Apple Watch found. Pair a Watch in the Watch app.")
            $0.alert = AlertState {
                TextState("Couldn't send to Watch")
            } message: {
                TextState("No paired Apple Watch found. Pair a Watch in the Watch app.")
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
