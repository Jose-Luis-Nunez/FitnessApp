import Testing
import Combine
import Foundation
@testable import FitnessExercise
import FitnessCore

private func makeExercise(
    id: UUID = UUID(),
    name: String = "Bicep Curl",
    weight: Double = 20,
    reps: Int = 10,
    sets: Int = 3,
    isCompleted: Bool = false
) -> Exercise {
    Exercise(
        id: id,
        name: name,
        weight: weight,
        reps: reps,
        sets: sets,
        isCompleted: isCompleted,
        iconName: "defaultArmsIcon",
        category: .arms
    )
}

// MARK: - syncExercise

@Suite("syncExercise")
struct SyncExerciseTests {

    @Test func publishesObjectWillChangeWhenContentDiffers() {
        let exercise = makeExercise()
        let vm = ExerciseCardViewModel(exercise: exercise) { _ in }

        var changeCount = 0
        let cancellable = vm.objectWillChange.sink { changeCount += 1 }

        var updated = exercise
        updated.isCompleted = true
        vm.syncExercise(updated)

        #expect(changeCount >= 1)
        #expect(vm.exercise.isCompleted == true)
        _ = cancellable
    }

    @Test func doesNotCallOnUpdate() {
        let exercise = makeExercise()
        var onUpdateCalled = false
        let vm = ExerciseCardViewModel(exercise: exercise) { _ in
            onUpdateCalled = true
        }

        var updated = exercise
        updated.weight = 999
        vm.syncExercise(updated)

        #expect(!onUpdateCalled)
        #expect(vm.exercise.weight == 999)
    }

    @Test func skipsUpdateWhenContentIsIdentical() {
        let exercise = makeExercise()
        let vm = ExerciseCardViewModel(exercise: exercise) { _ in }

        var changeCount = 0
        let cancellable = vm.objectWillChange.sink { changeCount += 1 }

        vm.syncExercise(exercise)

        #expect(changeCount == 0)
        _ = cancellable
    }

    @Test func detectsIsCompletedChange() {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let vm = ExerciseCardViewModel(exercise: original) { _ in }

        var completed = original
        completed.isCompleted = true

        vm.syncExercise(completed)

        #expect(vm.exercise.isCompleted == true)
    }
}

// MARK: - Direct mutation via update methods

@Suite("Direct mutation methods")
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
