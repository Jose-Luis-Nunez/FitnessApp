import Testing
import Foundation
@testable import FitnessExercise
import FitnessCore
import FitnessStorage
import FitnessTraining
import FitnessAnalytics
import FitnessTestSupport
import Factory

// MARK: - Mock Storage

@MainActor
private final class MockExerciseStorage: ExerciseStoring {
    var savedExercises: [MuscleCategoryGroup: [Exercise]] = [:]

    func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise] {
        savedExercises[category] ?? []
    }

    func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        savedExercises[category] = exercises
    }
}

@MainActor
private final class MockWorkoutStorage: WorkoutStoring {
    var workouts: [Workout] = []
    var currentWorkout: Workout?
    var defaultWorkout: Workout?

    func createWorkout(name: String, selectedCategories: Set<MuscleCategoryGroup>) -> Workout {
        let w = Workout(name: name, selectedCategories: selectedCategories)
        workouts.append(w)
        return w
    }
    func duplicateWorkout(_ workout: Workout) -> Workout { workout }
    func deleteWorkout(_ workout: Workout) {}
    func updateWorkout(_ workout: Workout) {}
    func setCurrentWorkout(_ workout: Workout) { currentWorkout = workout }
    func setAsDefaultWorkout(_ workout: Workout) { defaultWorkout = workout }
    func removeAsDefaultWorkout() { defaultWorkout = nil }
    func renameWorkout(_ workout: Workout, newName: String) {}
}

// MARK: - Helpers

@MainActor
private func makeVM(
    exercises: [Exercise] = [],
    coordinator: TrainingCoordinator? = nil
) -> (MuscleCategoryViewModel, MockExerciseStorage) {
    let storage = MockExerciseStorage()
    storage.savedExercises[.arms] = exercises
    let workoutStorage = MockWorkoutStorage()
    let testWorkout = Workout(name: "Test", selectedCategories: [.arms])
    workoutStorage.currentWorkout = testWorkout
    workoutStorage.workouts = [testWorkout]
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

    @Test func cachedCardViewModelReflectsRefreshedState() throws {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let (vm, storage) = makeVM(exercises: [original])

        let cardVM = vm.cardViewModel(for: original)
        #expect(cardVM.exercise.isCompleted == false)

        var completed = original
        completed.isCompleted = true
        storage.savedExercises[.arms] = [completed]

        vm.refreshExercises()

        let refreshed = try #require(vm.exercises.first, "exercises should not be empty after refresh")
        let sameCardVM = vm.cardViewModel(for: refreshed)
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
    return TrainingCoordinator(
        findCategory: { _ in .arms },
        onExerciseUpdate: { _, _ in },
        onExerciseReset: { _, _ in }
    )
}

@Suite("observer stability — exercises must survive coordinator state changes")
@MainActor
struct ObserverStabilityTests {

    @Test func startTrainingDoesNotRemoveExercises() async throws {
        let ex1 = makeExercise(name: "Curl")
        let ex2 = makeExercise(name: "Press")
        let ex3 = makeExercise(name: "Fly")
        let coordinator = makeCoordinator()
        let (vm, _) = makeVM(exercises: [ex1, ex2, ex3], coordinator: coordinator)

        #expect(vm.exercises.count == 3)

        await Task.yield()

        coordinator.startTraining(for: ex1)

        try await waitUntil { coordinator.activeSessions[ex1.id] != nil }
        try await Task.sleep(for: .milliseconds(100))

        #expect(vm.exercises.count == 3)
        #expect(vm.exercises.contains(where: { $0.id == ex1.id }))
        #expect(vm.exercises.contains(where: { $0.id == ex2.id }))
        #expect(vm.exercises.contains(where: { $0.id == ex3.id }))
    }

    @Test func cancelTrainingDoesNotRemoveExercises() async throws {
        let ex1 = makeExercise(name: "Curl")
        let ex2 = makeExercise(name: "Press")
        let coordinator = makeCoordinator()
        let (vm, _) = makeVM(exercises: [ex1, ex2], coordinator: coordinator)

        await Task.yield()

        coordinator.startTraining(for: ex1)
        try await waitUntil { coordinator.activeSessions[ex1.id] != nil }

        #expect(vm.exercises.count == 2)

        coordinator.cancelTraining(for: ex1.id)
        try await waitUntil { coordinator.activeSessions[ex1.id] == nil }
        try await Task.sleep(for: .milliseconds(100))

        #expect(vm.exercises.count == 2)
        #expect(vm.exercises.contains(where: { $0.id == ex1.id }))
        #expect(vm.exercises.contains(where: { $0.id == ex2.id }))
    }

    @Test func onlyCompletedExerciseUpdatesOthersStayUntouched() async throws {
        let ex1 = makeExercise(name: "Curl")
        let ex2 = makeExercise(name: "Press")
        let ex3 = makeExercise(name: "Fly")
        let coordinator = makeCoordinator()
        let (vm, _) = makeVM(exercises: [ex1, ex2, ex3], coordinator: coordinator)

        await Task.yield()

        coordinator.startTraining(for: ex1)
        try await waitUntil { coordinator.currentExercise != nil }

        for _ in 0..<ex1.sets {
            coordinator.completeSet()
        }
        coordinator.finishExercise()

        try await waitUntil { vm.exercises.first(where: { $0.id == ex1.id })?.isCompleted == true }

        let completedEx = try #require(vm.exercises.first(where: { $0.id == ex1.id }))
        #expect(completedEx.isCompleted == true)

        let untouched2 = try #require(vm.exercises.first(where: { $0.id == ex2.id }))
        #expect(untouched2.isCompleted == false)
        #expect(untouched2.name == "Press")

        let untouched3 = try #require(vm.exercises.first(where: { $0.id == ex3.id }))
        #expect(untouched3.isCompleted == false)
        #expect(untouched3.name == "Fly")
    }

    @Test func exerciseCountStableAcrossMultipleSessionChanges() async throws {
        let ex1 = makeExercise(name: "Curl")
        let ex2 = makeExercise(name: "Press")
        let coordinator = makeCoordinator()
        let (vm, _) = makeVM(exercises: [ex1, ex2], coordinator: coordinator)

        await Task.yield()

        coordinator.startTraining(for: ex1)
        try await waitUntil { coordinator.activeSessions[ex1.id] != nil }
        try await Task.sleep(for: .milliseconds(50))
        #expect(vm.exercises.count == 2)

        coordinator.startTraining(for: ex2)
        try await waitUntil { coordinator.activeSessions[ex2.id] != nil }
        try await Task.sleep(for: .milliseconds(50))
        #expect(vm.exercises.count == 2)

        coordinator.cancelTraining(for: ex1.id)
        try await waitUntil { coordinator.activeSessions[ex1.id] == nil }
        try await Task.sleep(for: .milliseconds(50))
        #expect(vm.exercises.count == 2)

        coordinator.cancelTraining(for: ex2.id)
        try await waitUntil { coordinator.activeSessions[ex2.id] == nil }
        try await Task.sleep(for: .milliseconds(50))
        #expect(vm.exercises.count == 2)
    }
}

@Suite("auto-refresh after exercise completion")
@MainActor
struct AutoRefreshTests {

    @Test func updatesExerciseInPlaceWhenCoordinatorCompletesIt() async throws {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let coordinator = makeCoordinator()
        let (vm, _) = makeVM(exercises: [original], coordinator: coordinator)

        await Task.yield()

        coordinator.startTraining(for: original)
        #expect(coordinator.isTrainingActive == true)

        try await waitUntil { coordinator.currentExercise != nil }

        for _ in 0..<original.sets {
            coordinator.completeSet()
        }
        coordinator.finishExercise()

        try await waitUntil { vm.exercises.first?.isCompleted == true }

        #expect(vm.exercises.first?.isCompleted == true)
        #expect(coordinator.lastCompletedExercise?.id == id)
    }

    @Test func doesNotUpdateWhenNoExerciseCompleted() async throws {
        let original = makeExercise(isCompleted: false)
        let coordinator = makeCoordinator()
        let (vm, _) = makeVM(exercises: [original], coordinator: coordinator)

        #expect(coordinator.lastCompletedExercise == nil)

        try await Task.sleep(for: .milliseconds(200))

        #expect(vm.exercises.first?.isCompleted == false)
    }

    @Test func cachedCardViewModelUpdatesAfterCompletion() async throws {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let coordinator = makeCoordinator()
        let (vm, _) = makeVM(exercises: [original], coordinator: coordinator)

        let cardVM = vm.cardViewModel(for: original)
        #expect(cardVM.exercise.isCompleted == false)

        await Task.yield()

        coordinator.startTraining(for: original)

        try await waitUntil { coordinator.currentExercise != nil }

        for _ in 0..<original.sets {
            coordinator.completeSet()
        }
        coordinator.finishExercise()

        try await waitUntil { vm.exercises.first?.isCompleted == true }

        let refreshedExercise = try #require(vm.exercises.first, "exercises should not be empty after finishExercise")
        let sameCardVM = vm.cardViewModel(for: refreshedExercise)
        #expect(cardVM === sameCardVM)
        #expect(cardVM.exercise.isCompleted == true)
    }

    @Test func ignoresCompletionForUnknownExerciseId() async throws {
        let knownExercise = makeExercise(name: "Curl")
        let unknownExercise = makeExercise(name: "Unknown")
        let coordinator = makeCoordinator()
        let (vm, _) = makeVM(exercises: [knownExercise], coordinator: coordinator)

        await Task.yield()

        coordinator.startTraining(for: unknownExercise)
        try await waitUntil { coordinator.currentExercise != nil }

        for _ in 0..<unknownExercise.sets {
            coordinator.completeSet()
        }
        coordinator.finishExercise()

        try await waitUntil { coordinator.lastCompletedExercise != nil }
        try await Task.sleep(for: .milliseconds(100))

        #expect(vm.exercises.count == 1)
        #expect(vm.exercises.first?.id == knownExercise.id)
        #expect(vm.exercises.first?.isCompleted == false)
    }
}
