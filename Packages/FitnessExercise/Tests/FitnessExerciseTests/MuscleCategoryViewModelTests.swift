import Testing
import Foundation
@testable import FitnessExercise
import FitnessCore
import FitnessStorage
import FitnessTraining
import FitnessAnalytics
import Factory

// MARK: - Mock Storage

@MainActor
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

@MainActor
private func makeVM(
    exercises: [Exercise] = [],
    coordinator: TrainingCoordinator? = nil
) -> (MuscleCategoryViewModel, MockExerciseStorage) {
    Container.shared.reset()
    let storage = MockExerciseStorage()
    let workoutStorage = Container.shared.workoutStorage()
    let activeSetVM = coordinator?.activeSetViewModel ?? ActiveSetViewModel()
    let vm = MuscleCategoryViewModel(
        group: .arms,
        exercises: exercises,
        storageService: storage,
        workoutStorageService: workoutStorage,
        activeSetViewModel: activeSetVM,
        coordinator: coordinator
    )
    return (vm, storage)
}

// MARK: - CardViewModel Cache

@Suite("cardViewModel cache")
@MainActor
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
@MainActor
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
@MainActor
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
@MainActor
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

// MARK: - refreshExercises (external change detection)

@Suite("refreshExercises")
@MainActor
struct RefreshExercisesTests {

    @Test func picksUpExternalCompletionChange() {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let (vm, storage) = makeVM(exercises: [original])

        #expect(vm.exercises.first?.isCompleted == false)

        var completed = original
        completed.isCompleted = true
        storage.savedExercises[.arms] = [completed]

        vm.refreshExercises()

        #expect(vm.exercises.first?.isCompleted == true)
    }

    @Test func cachedCardViewModelReflectsRefreshedState() {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let (vm, storage) = makeVM(exercises: [original])

        let cardVM = vm.cardViewModel(for: original)
        #expect(cardVM.exercise.isCompleted == false)

        var completed = original
        completed.isCompleted = true
        storage.savedExercises[.arms] = [completed]

        vm.refreshExercises()

        let sameCardVM = vm.cardViewModel(for: vm.exercises.first!)
        #expect(cardVM === sameCardVM)
        #expect(cardVM.exercise.isCompleted == true)
    }

    @Test func refreshDoesNotLoseExercisesAddedExternally() {
        let existing = makeExercise(name: "Curl")
        let (vm, storage) = makeVM(exercises: [existing])

        let added = makeExercise(name: "Press")
        storage.savedExercises[.arms] = [existing, added]

        vm.refreshExercises()

        #expect(vm.exercises.count == 2)
        #expect(vm.exercises.contains(where: { $0.name == "Press" }))
    }

    @Test func refreshRemovesExternallyDeletedExercises() {
        let ex1 = makeExercise(name: "Curl")
        let ex2 = makeExercise(name: "Press")
        let (vm, storage) = makeVM(exercises: [ex1, ex2])

        storage.savedExercises[.arms] = [ex1]

        vm.refreshExercises()

        #expect(vm.exercises.count == 1)
        #expect(vm.exercises.first?.name == "Curl")
    }
}

// MARK: - Auto-refresh on external training completion

@MainActor
private func makeCoordinator() -> TrainingCoordinator {
    let activeSetVM = ActiveSetViewModel()
    return TrainingCoordinator(
        findCategory: { _ in .arms },
        onExerciseUpdate: { _, _ in },
        onExerciseReset: { _, _ in },
        activeSetViewModel: activeSetVM
    )
}

@Suite("auto-refresh after external training finish")
@MainActor
struct AutoRefreshTests {

    @Test func refreshesWhenCoordinatorTrainingEnds() async throws {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let coordinator = makeCoordinator()
        let (vm, storage) = makeVM(exercises: [original], coordinator: coordinator)

        // Allow observation task to start and register tracking
        try await Task.yield()

        coordinator.startTraining(for: original)
        #expect(coordinator.isTrainingActive == true)

        // Allow the observation to see the active state and re-register
        try await Task.yield()
        try await Task.sleep(for: .milliseconds(50))

        // Simulate: TrainingView completes the exercise and writes to storage
        var completed = original
        completed.isCompleted = true
        storage.savedExercises[.arms] = [completed]

        // Complete all sets then finish
        for _ in 0..<original.sets {
            coordinator.completeSet()
        }
        coordinator.finishExercise()
        #expect(coordinator.isTrainingActive == false)

        // Allow the observation to detect the transition and run refreshExercises
        try await Task.yield()
        try await Task.sleep(for: .milliseconds(100))

        #expect(vm.exercises.first?.isCompleted == true)
    }

    @Test func doesNotRefreshWhenNoTrainingWasActive() async throws {
        let original = makeExercise(isCompleted: false)
        let coordinator = makeCoordinator()
        let (vm, storage) = makeVM(exercises: [original], coordinator: coordinator)

        #expect(coordinator.isTrainingActive == false)

        var completed = original
        completed.isCompleted = true
        storage.savedExercises[.arms] = [completed]

        try await Task.sleep(for: .milliseconds(350))

        #expect(vm.exercises.first?.isCompleted == false)
    }

    @Test func cachedCardViewModelUpdatesAfterAutoRefresh() async throws {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let coordinator = makeCoordinator()
        let (vm, storage) = makeVM(exercises: [original], coordinator: coordinator)

        let cardVM = vm.cardViewModel(for: original)
        #expect(cardVM.exercise.isCompleted == false)

        // Allow observation task to start and register tracking
        try await Task.yield()

        coordinator.startTraining(for: original)

        // Allow the observation to see the active state and re-register
        try await Task.yield()
        try await Task.sleep(for: .milliseconds(50))

        var completed = original
        completed.isCompleted = true
        storage.savedExercises[.arms] = [completed]

        for _ in 0..<original.sets {
            coordinator.completeSet()
        }
        coordinator.finishExercise()

        // Allow the observation to detect the transition and run refreshExercises
        try await Task.yield()
        try await Task.sleep(for: .milliseconds(100))

        let refreshedExercise = vm.exercises.first!
        let sameCardVM = vm.cardViewModel(for: refreshedExercise)
        #expect(cardVM === sameCardVM)
        #expect(cardVM.exercise.isCompleted == true)
    }
}
