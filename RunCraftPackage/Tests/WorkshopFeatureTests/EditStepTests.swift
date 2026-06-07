import ComposableArchitecture
import RunCraftModels
import Testing
@testable import WorkshopFeature

@MainActor
@Suite("EditStep reducer")
struct EditStepTests {

    // MARK: - isValid logic

    @Test("Open-ended goal is always valid")
    func openEnded_valid() {
        var state = EditStep.State(step: WorkoutStep(kind: .work, goal: .openEnded))
        state.goalUnit = .openEnded
        #expect(state.isValid)
    }

    @Test("Distance goal requires distance > 0")
    func distance_validation() {
        var state = EditStep.State(step: WorkoutStep(kind: .work, goal: .distance(metres: 1_000)))
        state.goalUnit = .distance
        state.distanceMetres = 1_000
        #expect(state.isValid)

        state.distanceMetres = 0
        #expect(!state.isValid)
    }

    @Test("Time goal requires total seconds > 0")
    func time_validation() {
        var state = EditStep.State(step: WorkoutStep(kind: .work, goal: .time(seconds: 600)))
        state.goalUnit = .time
        state.minutes = 10
        state.seconds = 0
        #expect(state.isValid)

        state.minutes = 0
        state.seconds = 0
        #expect(!state.isValid)

        state.minutes = 0
        state.seconds = 30
        #expect(state.isValid)
    }

    @Test("Pace alert requires max ≥ min")
    func paceAlert_validation() {
        var state = EditStep.State(step: WorkoutStep(kind: .work, goal: .distance(metres: 400)))
        state.goalUnit = .distance
        state.distanceMetres = 400
        state.alertKind = .pace
        state.paceMinSec = 300
        state.paceMaxSec = 320
        #expect(state.isValid)

        state.paceMaxSec = 280   // max < min
        #expect(!state.isValid)
    }

    // MARK: - Binding updates step.goal

    @Test("Switching to distance unit updates the underlying step.goal")
    func goalUnitChange_updatesStepGoal() async {
        let store = TestStore(initialState: EditStep.State(
            step: WorkoutStep(kind: .work, goal: .time(seconds: 600))
        )) {
            EditStep()
        }

        await store.send(\.binding.goalUnit, .distance) {
            $0.goalUnit = .distance
            $0.step.goal = .distance(metres: 1_000)
        }
    }

    @Test("Switching alert to pace updates step.alert with current min/max")
    func alertKindChange_updatesStepAlert() async {
        let store = TestStore(initialState: EditStep.State(
            step: WorkoutStep(kind: .work, goal: .distance(metres: 400))
        )) {
            EditStep()
        }

        await store.send(\.binding.alertKind, .pace) {
            $0.alertKind = .pace
            $0.step.alert = .paceRange(minSecPerKm: 360, maxSecPerKm: 420)
        }
    }
}
