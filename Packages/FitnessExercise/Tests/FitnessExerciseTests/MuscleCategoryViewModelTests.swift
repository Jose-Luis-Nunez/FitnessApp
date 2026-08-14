import Testing
import Foundation
import Observation
@testable import FitnessExercise
import FitnessCore
import FitnessStorage
import FitnessTraining
import FitnessAnalytics
import FitnessTestSupport

// MARK: - Mock Storage

@Observable
@MainActor
/// NOTE: Intentional local variant of `FitnessTestSupport.MockExerciseStorage`.
/// The 16 test call-sites in this file use `storage.savedExercises[.arms] = ...` as a
/// test-DSL idiom. The shared support type exposes the same shape under the name
/// `exercisesByCategory`; renaming here would be a 16-point churn with no functional
/// gain. Keep this file-private alias until the Support variant is restructured.
private final class MockExerciseStorage: ExerciseStoring {
    var savedExercises: [MuscleCategoryGroup: [Exercise]] = [:]
    private(set) var updateCalls: [Exercise] = []

    func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise] {
        savedExercises[category] ?? []
    }

    func exerciseCountsByWorkout() -> [UUID: Int] {
        [:]
    }

    func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        savedExercises[category] = exercises
    }

    func updateExercise(_ exercise: Exercise) {
        updateCalls.append(exercise)
        for (category, exercises) in savedExercises {
            if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                savedExercises[category]?[index] = exercise
                return
            }
        }
    }
}

// (MockWorkoutStorage is reused from FitnessTestSupport — the stateful mock
// with create/delete/duplicate/rename semantics is a strict superset of the
// previous file-private version.)

// MARK: - Helpers

@MainActor
private func makeVM(
    exercises: [Exercise] = [],
    coordinator: TrainingCoordinator? = nil,
    storage: MockExerciseStorage? = nil
) -> (MuscleCategoryViewModel, MockExerciseStorage) {
    let storage = storage ?? MockExerciseStorage()
    if storage.savedExercises[.arms] == nil {
        storage.savedExercises[.arms] = exercises
    }
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

// MARK: - updateExercise

@Suite("updateExercise", .tags(.fast))
@MainActor
struct UpdateExerciseTests {

    @Test func updateExerciseChangesArrayAndPersistsTargetedRow() {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let (vm, storage) = makeVM(exercises: [original])

        var updated = original
        updated.isCompleted = true
        updated.weight = 99
        vm.updateExercise(updated)

        #expect(vm.exercises.first?.isCompleted == true)
        let saved = storage.savedExercises[.arms]
        #expect(saved?.first?.weight == 99)
        #expect(storage.updateCalls.map(\.id) == [id])
    }

    @Test func ignoresUnknownExercise() {
        let (vm, _) = makeVM(exercises: [makeExercise()])
        let unknown = makeExercise(name: "Unknown")
        vm.updateExercise(unknown)

        #expect(vm.exercises.count == 1)
    }
}

// MARK: - resetProgress

@Suite("resetProgress", .tags(.fast))
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

@Suite("exercise collection lifecycle", .tags(.fast))
@MainActor
struct ExerciseCollectionLifecycleTests {

    @Test func addAndDeletePersistTheOrderedCollection() {
        let existing = makeExercise(name: "Existing")
        let first = makeExercise(name: "First")
        let last = makeExercise(name: "Last")
        let (vm, storage) = makeVM(exercises: [existing])

        vm.add(first, atTop: true)
        vm.add(last, atTop: false)
        #expect(vm.exercises.map(\.name) == ["First", "Existing", "Last"])
        #expect(storage.savedExercises[.arms]?.map(\.name) == ["First", "Existing", "Last"])

        vm.deleteExercise(existing)
        #expect(vm.exercises.map(\.name) == ["First", "Last"])
        #expect(storage.savedExercises[.arms]?.map(\.name) == ["First", "Last"])
    }

    @Test func resetAndActivationUseTargetedUpdatesAndIgnoreNoOps() {
        let completed = makeExercise(isCompleted: true)
        let (vm, storage) = makeVM(exercises: [completed])

        vm.resetExercise(completed)
        let reset = vm.exercises[0]
        #expect(!reset.isCompleted)

        vm.setExerciseActive(reset, active: false)
        let deactivated = vm.exercises[0]
        #expect(!deactivated.isActive)

        let callsBeforeNoOp = storage.updateCalls.count
        vm.setExerciseActive(deactivated, active: false)
        #expect(storage.updateCalls.count == callsBeforeNoOp)
    }

    @Test func visibilityFlagsFollowCompletionAndTrainingState() {
        let exercise = makeExercise()
        let coordinator = TrainingCoordinator(
            findCategory: { _ in .arms },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in }
        )
        let (vm, _) = makeVM(exercises: [exercise], coordinator: coordinator)

        #expect(vm.showNewExercise)
        #expect(vm.showStartTraining)
        #expect(!vm.showCancel)
        #expect(!vm.showReset)

        coordinator.startTraining(for: exercise)
        #expect(vm.showCancel)
        #expect(!vm.showNewExercise)
        #expect(!vm.showStartTraining)
        #expect(!vm.showReset)

        coordinator.cancelTraining(for: exercise.id)
        var completed = exercise
        completed.isCompleted = true
        vm.updateExercise(completed)
        #expect(!vm.showCancel)
        #expect(!vm.showStartTraining)
        #expect(vm.showReset)
    }
}

// MARK: - refreshExercises (external change detection)

@Suite("refreshExercises", .tags(.fast))
@MainActor
struct RefreshExercisesTests {

    @Test func refreshReplacesSnapshotAcrossChangeAdditionAndDeletion() {
        let id = UUID()
        let original = makeExercise(id: id, isCompleted: false)
        let (vm, storage) = makeVM(exercises: [original])

        #expect(vm.exercises.first?.isCompleted == false)

        var completed = original
        completed.isCompleted = true
        storage.savedExercises[.arms] = [completed]

        vm.refreshExercises()

        #expect(vm.exercises.first?.isCompleted == true)
        let added = makeExercise(name: "Press")
        storage.savedExercises[.arms] = [completed, added]

        vm.refreshExercises()

        #expect(vm.exercises.count == 2)
        #expect(vm.exercises.contains(where: { $0.name == "Press" }))
        storage.savedExercises[.arms] = [added]

        vm.refreshExercises()

        #expect(vm.exercises.count == 1)
        #expect(vm.exercises.first?.name == "Press")
    }
}

// MARK: - Auto-refresh on external training completion

@MainActor
private final class StorageBackedExerciseManagementSpy: ExerciseManaging {
    private let storage: MockExerciseStorage
    private(set) var updatedExercises: [Exercise] = []

    init(storage: MockExerciseStorage) {
        self.storage = storage
    }

    func updateExercise(_ updatedExercise: Exercise, category: MuscleCategoryGroup) {
        updatedExercises.append(updatedExercise)
        storage.updateExercise(updatedExercise)
    }

    func getExercises(for category: MuscleCategoryGroup) -> [Exercise] {
        storage.savedExercises[category] ?? []
    }

    func addExercise(_ exercise: Exercise, category: MuscleCategoryGroup, atTop: Bool) {}
    func completeExercise(_ exercise: Exercise, category: MuscleCategoryGroup, setProgress: [SetProgress]) {}
    func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {}
    func resetAllExercises(for categories: [MuscleCategoryGroup]) {}
    func getExerciseCount(for category: MuscleCategoryGroup) -> (total: Int, active: Int) { (0, 0) }
    func getAllExerciseCounts(for categories: [MuscleCategoryGroup]) -> [MuscleCategoryGroup: (total: Int, active: Int)] { [:] }
    func hasInactiveExercises(for categories: [MuscleCategoryGroup]) -> Bool { false }
}

@Suite("observer stability — exercises must survive coordinator state changes", .tags(.fast))
@MainActor
struct ObserverStabilityTests {
    @Test func productionCachePersistsOnlyCompletedExercise() throws {
        let ex1 = makeExercise(name: "Curl")
        let ex2 = makeExercise(name: "Press")
        let ex3 = makeExercise(name: "Fly")
        let storage = MockExerciseStorage()
        storage.savedExercises[.arms] = [ex1, ex2, ex3]
        let management = StorageBackedExerciseManagementSpy(storage: storage)
        let analyticsViewModel = AnalyticsViewModel(
            storageService: StubAnalyticsStorage(),
            exerciseStorage: storage,
            workoutStorage: MockWorkoutStorage()
        )
        let cache = TrainingCoordinatorCache(
            exerciseManagement: management,
            analyticsViewModel: analyticsViewModel
        )
        let coordinator = cache.coordinator(for: .arms)
        let (vm, _) = makeVM(exercises: [ex1, ex2, ex3], coordinator: coordinator, storage: storage)

        coordinator.startTraining(for: ex1)

        for _ in 0..<ex1.sets {
            coordinator.completeSet()
        }
        coordinator.finishExercise()
        vm.refreshExercises()

        #expect(management.updatedExercises.map(\.id) == [ex1.id])
        let completedEx = try #require(vm.exercises.first(where: { $0.id == ex1.id }))
        #expect(completedEx.isCompleted == true)

        let untouched2 = try #require(vm.exercises.first(where: { $0.id == ex2.id }))
        #expect(untouched2.isCompleted == false)
        #expect(untouched2.name == "Press")

        let untouched3 = try #require(vm.exercises.first(where: { $0.id == ex3.id }))
        #expect(untouched3.isCompleted == false)
        #expect(untouched3.name == "Fly")
    }

}

// MARK: - Current Workout ID Exposure (T7b)

@MainActor
@Suite("MuscleCategoryViewModel.currentWorkoutId", .tags(.fast))
struct MuscleCategoryViewModelCurrentWorkoutIdTests {

    private func makeVMOnly(workoutStorage: MockWorkoutStorage) -> MuscleCategoryViewModel {
        MuscleCategoryViewModel(
            group: .arms,
            exercises: [],
            storageService: MockExerciseStorage(),
            workoutStorageService: workoutStorage,
            activeSetViewModel: ActiveSetViewModel()
        )
    }

    @Test func tracksCurrentWorkoutAcrossNilSelectionAndSwitch() {
        let ws = MockWorkoutStorage()
        let vm = makeVMOnly(workoutStorage: ws)
        #expect(vm.currentWorkoutId == nil)
        let w1 = Workout(name: "W1", selectedCategories: [.arms])
        let w2 = Workout(name: "W2", selectedCategories: [.chest])
        ws.setCurrentWorkout(w1)
        #expect(vm.currentWorkoutId == w1.id)

        ws.setCurrentWorkout(w2)
        #expect(vm.currentWorkoutId == w2.id)
    }
}
