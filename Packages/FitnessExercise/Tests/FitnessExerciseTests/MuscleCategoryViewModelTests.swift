import Testing
import Combine
import Foundation
@testable import FitnessExercise
import FitnessCore
import FitnessStorage
import FitnessTraining

// MARK: - Mock Storage

private final class MockExerciseStorage: ExerciseStoring {
    var savedExercises: [MuscleCategoryGroup: [Exercise]] = [:]

    func load(for group: MuscleCategoryGroup) -> [Exercise] {
        savedExercises[group] ?? []
    }

    func save(_ exercises: [Exercise], for group: MuscleCategoryGroup) {
        savedExercises[group] = exercises
    }

    func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise] {
        savedExercises[category] ?? []
    }

    func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        savedExercises[category] = exercises
    }
}

// MARK: - Helpers

private func makeExercise(
    id: UUID = UUID(),
    name: String = "Curl",
    isCompleted: Bool = false
) -> Exercise {
    Exercise(
        id: id,
        name: name,
        weight: 20,
        reps: 10,
        sets: 3,
        isCompleted: isCompleted,
        iconName: "defaultArmsIcon",
        category: .arms
    )
}

private func makeVM(exercises: [Exercise] = []) -> (MuscleCategoryViewModel, MockExerciseStorage) {
    let storage = MockExerciseStorage()
    let workoutStorage = WorkoutStorageService()
    let activeSetVM = ActiveSetViewModel()
    let vm = MuscleCategoryViewModel(
        group: .arms,
        exercises: exercises,
        storageService: storage,
        workoutStorageService: workoutStorage,
        activeSetViewModel: activeSetVM
    )
    return (vm, storage)
}

// MARK: - CardViewModel Cache

@Suite("cardViewModel cache")
struct CardViewModelCacheTests {

    @Test func returnsSameInstanceForSameExerciseID() {
        let exercise = makeExercise()
        let (vm, _) = makeVM(exercises: [exercise])

        let first = vm.cardViewModel(for: exercise)
        let second = vm.cardViewModel(for: exercise)

        #expect(first === second)
    }

    @Test func returnsDifferentInstancesForDifferentExercises() {
        let ex1 = makeExercise(name: "Curl")
        let ex2 = makeExercise(name: "Press")
        let (vm, _) = makeVM(exercises: [ex1, ex2])

        let vm1 = vm.cardViewModel(for: ex1)
        let vm2 = vm.cardViewModel(for: ex2)

        #expect(vm1 !== vm2)
    }

    @Test func syncsIsCompletedChangeToExistingCachedVM() {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let (vm, _) = makeVM(exercises: [original])

        let cardVM = vm.cardViewModel(for: original)
        #expect(cardVM.exercise.isCompleted == false)

        var updated = original
        updated.isCompleted = true
        let sameCardVM = vm.cardViewModel(for: updated)

        #expect(cardVM === sameCardVM)
        #expect(cardVM.exercise.isCompleted == true)
    }

    @Test func syncsWeightChangeToExistingCachedVM() {
        let id = UUID()
        let original = makeExercise(id: id)
        let (vm, _) = makeVM(exercises: [original])

        let cardVM = vm.cardViewModel(for: original)
        #expect(cardVM.exercise.weight == 20)

        var updated = original
        updated.weight = 50
        vm.cardViewModel(for: updated)

        #expect(cardVM.exercise.weight == 50)
    }

    @Test func syncDoesNotTriggerOnUpdateCallback() {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let (vm, storage) = makeVM(exercises: [original])

        _ = vm.cardViewModel(for: original)

        var updated = original
        updated.isCompleted = true

        let savedBefore = storage.savedExercises[.arms]
        _ = vm.cardViewModel(for: updated)

        // syncExercise must not call onUpdate -> updateExercise -> saveExercises
        #expect(storage.savedExercises[.arms] == savedBefore)
    }
}

// MARK: - updateExercise

@Suite("updateExercise")
struct UpdateExerciseTests {

    @Test func updatesExerciseInArray() {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let (vm, _) = makeVM(exercises: [original])

        var updated = original
        updated.isCompleted = true
        vm.updateExercise(updated)

        #expect(vm.exercises.first?.isCompleted == true)
    }

    @Test func savesAfterUpdate() {
        let id = UUID()
        let original = makeExercise(id: id)
        let (vm, storage) = makeVM(exercises: [original])

        var updated = original
        updated.weight = 99
        vm.updateExercise(updated)

        let saved = storage.savedExercises[.arms]
        #expect(saved?.first?.weight == 99)
    }

    @Test func ignoresUnknownExercise() {
        let (vm, _) = makeVM(exercises: [makeExercise()])
        let unknown = makeExercise(name: "Unknown")
        vm.updateExercise(unknown)

        #expect(vm.exercises.count == 1)
    }
}

// MARK: - resetProgress

@Suite("resetProgress")
struct ResetProgressTests {

    @Test func clearsIsCompletedOnAllExercises() {
        let ex1 = makeExercise(isCompleted: true)
        let ex2 = makeExercise(isCompleted: true)
        let (vm, _) = makeVM(exercises: [ex1, ex2])

        vm.resetProgress()

        #expect(vm.exercises.allSatisfy { !$0.isCompleted })
    }
}

// MARK: - invalidateCardViewModels

@Suite("invalidateCardViewModels")
struct InvalidateCacheTests {

    @Test func newInstanceAfterInvalidation() {
        let exercise = makeExercise()
        let (vm, _) = makeVM(exercises: [exercise])

        let first = vm.cardViewModel(for: exercise)
        vm.invalidateCardViewModels()
        let second = vm.cardViewModel(for: exercise)

        #expect(first !== second)
    }
}
