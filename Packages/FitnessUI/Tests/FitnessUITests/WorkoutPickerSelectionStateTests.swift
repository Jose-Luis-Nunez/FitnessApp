import FitnessCore
import Testing
@testable import FitnessUI

@Suite("WorkoutPicker selection")
struct WorkoutPickerSelectionStateTests {
    @Test("A row tap confirms the current wheel selection")
    func rowTapConfirmsCurrentWheelSelection() {
        let previous = Workout(name: "Previous")
        let tapped = Workout(name: "Tapped")
        var state = WorkoutPickerSelectionState()
        state.select(previous)
        state.select(tapped)

        let confirmed = state.confirm()

        #expect(confirmed == tapped)
        #expect(state.selectedWorkout == tapped)
    }

    @Test("Wheel selection alone does not confirm")
    func wheelSelectionRemainsLocal() {
        let scrolledTo = Workout(name: "Scrolled")
        var state = WorkoutPickerSelectionState()

        state.select(scrolledTo)

        #expect(state.selectedWorkout == scrolledTo)
        #expect(!state.hasConfirmedSelection)
    }

    @Test("Fast duplicate confirmation emits only once")
    func duplicateConfirmationIsSuppressed() {
        let workout = Workout(name: "Once")
        var state = WorkoutPickerSelectionState()
        state.select(workout)

        #expect(state.confirm() == workout)
        #expect(state.confirm() == nil)
    }
}
