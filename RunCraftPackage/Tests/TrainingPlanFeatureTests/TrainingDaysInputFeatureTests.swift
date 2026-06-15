import ComposableArchitecture
import Foundation
import Testing
import TrainingPlanFeature

@MainActor
@Suite("TrainingDaysInput — dayToggled")
struct TrainingDaysInputFeatureTests {

    @Test("Toggling an unselected day adds it")
    func toggleAdds() async {
        var state = TrainingDaysInput.State()
        state.availableDays = [1, 2, 3, 4, 5]

        let store = TestStore(initialState: state) {
            TrainingDaysInput()
        }

        await store.send(.dayToggled(6)) {
            $0.availableDays.insert(6)
        }
    }

    @Test("Toggling a selected day removes it")
    func toggleRemoves() async {
        let store = TestStore(initialState: TrainingDaysInput.State()) {
            TrainingDaysInput()
        }

        await store.send(.dayToggled(3)) {
            $0.availableDays.remove(3)
        }
    }

    @Test("Refuses to drop below 1 day")
    func refusesBelowOneDay() async {
        var state = TrainingDaysInput.State()
        state.availableDays = [4]

        let store = TestStore(initialState: state) {
            TrainingDaysInput()
        }

        await store.send(.dayToggled(4))
    }

    @Test("Removing the long-run day clears the long-run preference")
    func removingLongRunDayClearsPreference() async {
        var state = TrainingDaysInput.State()
        state.longRunDay = 7

        let store = TestStore(initialState: state) {
            TrainingDaysInput()
        }

        await store.send(.dayToggled(7)) {
            $0.availableDays.remove(7)
            $0.longRunDay = nil
        }
    }
}
