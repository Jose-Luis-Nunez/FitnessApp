import Testing
import Foundation
@testable import FitnessExercise
import FitnessCore
import FitnessTestSupport

// MARK: - Direct mutation via update methods

@Suite("Direct mutation methods")
@MainActor
struct DirectMutationTests {

    @Test func updateWeightCallsOnUpdate() {
        let exercise = makeExercise()
        var received: Exercise?
        let vm = ExerciseCardViewModel(exercise: exercise) { received = $0 }

        vm.updateWeight(42)

        #expect(received?.weight == 42)
    }

    @Test func updateRepsCallsOnUpdate() {
        let exercise = makeExercise()
        var received: Exercise?
        let vm = ExerciseCardViewModel(exercise: exercise) { received = $0 }

        vm.updateReps(15)

        #expect(received?.reps == 15)
    }

    @Test func updateSetsCallsOnUpdate() {
        let exercise = makeExercise()
        var received: Exercise?
        let vm = ExerciseCardViewModel(exercise: exercise) { received = $0 }

        vm.updateSets(5)

        #expect(received?.sets == 5)
    }

    @Test func updateSeatCallsOnUpdate() {
        let exercise = makeExercise()
        var received: Exercise?
        let vm = ExerciseCardViewModel(exercise: exercise) { received = $0 }

        vm.updateSeat("3")

        #expect(received?.seatSetting == "3")
        #expect(received?.noSeats == false)
    }
}

// MARK: - didSet guard with id-only Equatable

@Suite("didSet guard uses content equality")
@MainActor
struct DidSetGuardTests {

    @Test func didSetFiresOnUpdateWhenContentChanges() {
        let exercise = makeExercise()
        var callCount = 0
        let vm = ExerciseCardViewModel(exercise: exercise) { _ in callCount += 1 }

        var modified = exercise
        modified.reps = 99
        vm.exercise = modified

        #expect(callCount == 1)
    }

    @Test func didSetSkipsOnUpdateWhenContentIsIdentical() {
        let exercise = makeExercise()
        var callCount = 0
        let vm = ExerciseCardViewModel(exercise: exercise) { _ in callCount += 1 }

        vm.exercise = exercise

        #expect(callCount == 0)
    }
}
