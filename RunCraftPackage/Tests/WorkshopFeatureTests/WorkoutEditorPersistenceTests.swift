import ComposableArchitecture
import Dependencies
import Foundation
import RunCraftModels
import Testing
@testable import WorkshopFeature

@MainActor
@Suite("WorkoutEditor persistence via Repository")
struct WorkoutEditorPersistenceTests {

    // Fixed UUID + Date generators so TestStore assertions are deterministic.
    private static let newId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let existingId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Save (insert)

    @Test("Save with no editingTemplateId calls repository.save once and adopts the returned id")
    func save_insertsAndAdoptsId() async {
        // Spy: capture the template the editor passes to the repo.
        let captured = ActorBox<WorkoutTemplate?>(nil)
        let store = TestStore(initialState: makeStateWithBlocks()) {
            WorkoutEditor()
        } withDependencies: {
            $0.uuid = .constant(Self.newId)
            $0.date.now = Self.now
            $0.workoutTemplateRepository = .testValue
            $0.workoutTemplateRepository.save = { @Sendable template in
                await captured.set(template)
                return template.id
            }
        }

        await store.send(.saveTapped) {
            $0.saveStatus = .saving
        }
        await store.receive(\.saveResponse.success) {
            $0.saveStatus = .saved
            $0.editingTemplateId = Self.newId
        }

        let template = await captured.value
        #expect(template?.id == Self.newId, "save was called with the new UUID")
        #expect(template?.name == "New Workout")
        #expect(template?.blocks.count == 1)
    }

    // MARK: - Save (update)

    @Test("Save with existing editingTemplateId reuses that id and does NOT mint a new UUID")
    func save_updatesExisting() async {
        var state = makeStateWithBlocks()
        state.editingTemplateId = Self.existingId

        let captured = ActorBox<UUID?>(nil)
        let store = TestStore(initialState: state) {
            WorkoutEditor()
        } withDependencies: {
            // If the reducer wrongly minted a new UUID we'd see this one — but it shouldn't.
            $0.uuid = .constant(Self.newId)
            $0.date.now = Self.now
            $0.workoutTemplateRepository = .testValue
            $0.workoutTemplateRepository.save = { @Sendable template in
                await captured.set(template.id)
                return template.id
            }
        }

        await store.send(.saveTapped) {
            $0.saveStatus = .saving
        }
        await store.receive(\.saveResponse.success) {
            $0.saveStatus = .saved
        }

        let id = await captured.value
        #expect(id == Self.existingId, "should preserve existingId, not mint .newId")
    }

    // MARK: - Save (empty blocks short-circuits)

    @Test("Save with empty blocks does nothing — no effect, no status change")
    func save_emptyBlocks_noOp() async {
        let store = TestStore(initialState: WorkoutEditor.State()) {
            WorkoutEditor()
        } withDependencies: {
            $0.workoutTemplateRepository = .testValue
            $0.workoutTemplateRepository.save = { @Sendable _ in
                Issue.record("repository.save should not be called for empty blocks")
                return UUID()
            }
        }

        await store.send(.saveTapped) // expect no state change, no receive
    }

    // MARK: - Save (failure path)

    @Test("Repository.save throwing surfaces as saveStatus.failed")
    func save_failurePath() async {
        struct SaveError: LocalizedError {
            var errorDescription: String? { "disk full" }
        }

        let store = TestStore(initialState: makeStateWithBlocks()) {
            WorkoutEditor()
        } withDependencies: {
            $0.uuid = .constant(Self.newId)
            $0.date.now = Self.now
            $0.workoutTemplateRepository = .testValue
            $0.workoutTemplateRepository.save = { @Sendable _ in throw SaveError() }
        }

        await store.send(.saveTapped) {
            $0.saveStatus = .saving
        }
        await store.receive(\.saveResponse.failure) {
            $0.saveStatus = .failed("disk full")
        }
    }

    // MARK: - Delete

    @Test("deleteTemplate forwards the id to repository.delete")
    func delete_callsRepo() async {
        let captured = ActorBox<UUID?>(nil)
        let store = TestStore(initialState: WorkoutEditor.State()) {
            WorkoutEditor()
        } withDependencies: {
            $0.workoutTemplateRepository = .testValue
            $0.workoutTemplateRepository.delete = { @Sendable id in
                await captured.set(id)
            }
        }

        await store.send(.deleteTemplate(Self.existingId))
        let captured_id = await captured.value
        #expect(captured_id == Self.existingId)
    }

    // MARK: - Helpers

    private func makeStateWithBlocks() -> WorkoutEditor.State {
        var s = WorkoutEditor.State()
        s.blocks = [
            .step(WorkoutStep(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                kind: .work,
                goal: .time(seconds: 600)
            )),
        ]
        return s
    }
}

/// Tiny actor box so test closures can capture/inspect values without `@unchecked Sendable`.
private actor ActorBox<T: Sendable> {
    private var inner: T
    init(_ initial: T) { inner = initial }
    var value: T { inner }
    func set(_ new: T) { inner = new }
}
