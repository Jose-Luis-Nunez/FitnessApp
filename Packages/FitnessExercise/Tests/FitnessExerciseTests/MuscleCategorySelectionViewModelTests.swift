import Testing
import Foundation
@testable import FitnessExercise
import FitnessCore
import FitnessTraining
import FitnessTestSupport
import Factory

// MARK: - Mock Coordinator Cache

@MainActor
private final class MockCoordinatorCache: TrainingCoordinatorCaching {
    private var coordinators: [MuscleCategoryGroup: TrainingCoordinator] = [:]

    func coordinator(for group: MuscleCategoryGroup) -> TrainingCoordinator {
        if let existing = coordinators[group] {
            return existing
        }
        let coordinator = TrainingCoordinator(
            findCategory: { _ in group },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in }
        )
        coordinators[group] = coordinator
        return coordinator
    }

    func findCoordinator(for exercise: Exercise) -> (TrainingCoordinator, MuscleCategoryGroup)? {
        for (group, coordinator) in coordinators {
            if coordinator.isExerciseInProgress(exercise.id) {
                return (coordinator, group)
            }
        }
        return nil
    }
}

// MARK: - Mock Exercise Management

// MockExerciseManagement is shared from FitnessTestSupport

// MARK: - Categories (workout-agnostic)

/// Product decision: the overview tile-grid always shows **all** muscle
/// categories regardless of `Workout.selectedCategories`. These tests pin
/// that contract so a future refactor does not silently re-introduce the
/// "single Abs tile" bug (where `categories` was sourced from
/// `workout.selectedCategories` and the per-category "New Exercise" menu
/// could write into categories the overview was hiding).
@Suite("categories are always all cases")
@MainActor
struct CategoriesTests {

    @Test func categoriesEqualAllCasesSortedByRawValue() {
        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms, .chest]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            workoutStorage: ws
        )

        let expected = MuscleCategoryGroup.allCases.sorted { $0.rawValue < $1.rawValue }
        #expect(vm.categories == expected)
    }

    @Test func categoriesIgnoreWorkoutSelectedCategories() {
        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "AbsOnly", selectedCategories: [.abs]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            workoutStorage: ws
        )

        #expect(vm.categories.count == MuscleCategoryGroup.allCases.count)
        #expect(vm.categories.contains(.arms))
        #expect(vm.categories.contains(.chest))
        #expect(vm.categories.contains(.back))
        #expect(vm.categories.contains(.legs))
        #expect(vm.categories.contains(.abs))
    }

    @Test func categoriesNonEmptyEvenWithoutWorkout() {
        let ws = MockWorkoutStorage()
        // currentWorkout intentionally nil
        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            workoutStorage: ws
        )
        #expect(vm.categories.count == MuscleCategoryGroup.allCases.count)
    }
}

// MARK: - Exercise Counts (with mocked ExerciseManaging)

@Suite("exercise counts")
@MainActor
struct ExerciseCountsTests {

    @Test func exerciseCountsReflectMockState() {
        let mock = MockExerciseManagement()
        mock.exercisesByCategory[.arms] = [makeExercise(), makeExercise(isCompleted: true)]

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )

        let count = vm.getExerciseCount(for: .arms)
        #expect(count?.total == 2)
        #expect(count?.active == 1)
    }

    @Test func exerciseCountsUpdateAfterTrainingEnds() async throws {
        let mock = MockExerciseManagement()
        let exercise = makeExercise(isCompleted: false)
        mock.exercisesByCategory[.arms] = [exercise]

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let cache = MockCoordinatorCache()
        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: cache,
            exerciseManagement: mock,
            workoutStorage: ws
        )
        #expect(vm.getExerciseCount(for: .arms)?.active == 1)

        await Task.yield()

        let coordinator = cache.coordinator(for: .arms)
        coordinator.startTraining(for: exercise)

        try await waitUntil(timeout: .seconds(2)) { coordinator.isTrainingActive }

        var completed = exercise
        completed.isCompleted = true
        mock.exercisesByCategory[.arms] = [completed]

        for _ in 0..<exercise.sets { coordinator.completeSet() }
        coordinator.finishExercise()

        // Polling-based auto-refresh was removed in T8d; the live UI uses
        // @Query on ExerciseModel for reactivity. Tests must request a
        // refresh explicitly to update the VM's snapshot.
        try await Task.sleep(for: .milliseconds(100))
        vm.refreshExercises()

        #expect(vm.getExerciseCount(for: .arms)?.active == 0)
    }

    @Test func manualUpdateCountsPicksUpChange() {
        let mock = MockExerciseManagement()
        let exercise = makeExercise(isCompleted: false)
        mock.exercisesByCategory[.arms] = [exercise]

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )
        #expect(vm.getExerciseCount(for: .arms)?.active == 1)

        var completed = exercise
        completed.isCompleted = true
        mock.exercisesByCategory[.arms] = [completed]

        vm.refreshExercises()
        #expect(vm.getExerciseCount(for: .arms)?.active == 0)
    }
}

// MARK: - Card ViewModel Cache

// MARK: - Reset All Exercises

@Suite("resetAllExercises")
@MainActor
struct ResetAllExercisesTests {

    @Test func resetAllExercises_whenNoCurrentWorkout_doesNotMutateExercises() {
        Container.shared.reset()

        let mock = MockExerciseManagement()
        let completed = makeExercise(isCompleted: true)
        mock.exercisesByCategory[.arms] = [completed]
        Container.shared.exerciseManagement.register { mock }

        let ws = MockWorkoutStorage()
        // currentWorkout intentionally left nil — guard in production code must short-circuit.

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )

        vm.resetAllExercises()

        // Invariant: without a currentWorkout the VM must not touch exercises.
        #expect(mock.exercisesByCategory[.arms]?.first?.isCompleted == true)
    }

    @Test func resetsExercisesAndUpdatesCounts() {
        Container.shared.reset()

        let mock = MockExerciseManagement()
        mock.exercisesByCategory[.arms] = [makeExercise(isCompleted: true)]
        Container.shared.exerciseManagement.register { mock }

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )
        #expect(vm.getExerciseCount(for: .arms)?.active == 0)

        vm.resetAllExercises()

        #expect(vm.getExerciseCount(for: .arms)?.active == 1)
    }
}

// MARK: - Find Category For Exercise

@Suite("findCategoryForExercise")
@MainActor
struct FindCategoryTests {

    @Test func findsCorrectCategory() {
        let mock = MockExerciseManagement()
        let exercise = makeExercise()
        mock.exercisesByCategory[.arms] = [exercise]

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms, .chest]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )
        #expect(vm.findCategoryForExercise(exercise) == .arms)
    }

    @Test func returnsNilForUnknownExercise() {
        let mock = MockExerciseManagement()

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )
        #expect(vm.findCategoryForExercise(makeExercise()) == nil)
    }
}

// MARK: - Exercise Mutations (Phase 1a)

@Suite("exercise mutations")
@MainActor
struct ExerciseMutationTests {

    @Test func updateExercisePatchesCountsAfterStorageWrite() {
        let mock = MockExerciseManagement()
        let exercise = makeExercise(isCompleted: false)
        mock.exercisesByCategory[.arms] = [exercise]

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )
        #expect(vm.getExerciseCount(for: .arms)?.active == 1)

        var completed = exercise
        completed.isCompleted = true
        vm.updateExercise(completed, category: .arms)

        #expect(vm.getExerciseCount(for: .arms)?.active == 0)
    }

    @Test func addExerciseAppearsInCounts() {
        let mock = MockExerciseManagement()
        mock.exercisesByCategory[.arms] = [makeExercise()]

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )
        #expect(vm.getExerciseCount(for: .arms)?.total == 1)

        vm.addExercise(makeExercise(name: "Tricep"), category: .arms)

        #expect(vm.getExerciseCount(for: .arms)?.total == 2)
    }

    @Test func resetExerciseClearsCompletion() {
        let mock = MockExerciseManagement()
        let exercise = makeExercise(isCompleted: true)
        mock.exercisesByCategory[.arms] = [exercise]

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )
        #expect(vm.getExerciseCount(for: .arms)?.active == 0)

        vm.resetExercise(exercise, category: .arms)

        #expect(vm.getExerciseCount(for: .arms)?.active == 1)
    }

    @Test func getExercisesReturnsCurrentData() {
        let mock = MockExerciseManagement()
        let ex1 = makeExercise(name: "Curl")
        let ex2 = makeExercise(name: "Press")
        mock.exercisesByCategory[.arms] = [ex1, ex2]

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )
        let exercises = vm.getExercises(for: .arms)

        #expect(exercises.count == 2)
        #expect(exercises[0].name == "Curl")
        #expect(exercises[1].name == "Press")
    }
}

// MARK: - Exercise Stability Across Sessions (Phase 1c)

@Suite("exercise stability across sessions")
@MainActor
struct ExerciseStabilityTests {

    @Test func startTrainingDoesNotAffectExerciseData() async throws {
        let mock = MockExerciseManagement()
        let exercise = makeExercise()
        mock.exercisesByCategory[.arms] = [exercise]

        let cache = MockCoordinatorCache()

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: cache,
            exerciseManagement: mock,
            workoutStorage: ws
        )
        let countBefore = vm.getExerciseCount(for: .arms)
        let exercisesBefore = vm.getExercises(for: .arms)

        let coordinator = cache.coordinator(for: .arms)
        coordinator.startTraining(for: exercise)
        try await waitUntil(timeout: .seconds(2)) { coordinator.isTrainingActive }

        #expect(vm.getExerciseCount(for: .arms)?.total == countBefore?.total)
        #expect(vm.getExerciseCount(for: .arms)?.active == countBefore?.active)
        #expect(vm.getExercises(for: .arms).count == exercisesBefore.count)
    }

    @Test func cancelTrainingDoesNotAffectExerciseData() async throws {
        let mock = MockExerciseManagement()
        let exercise = makeExercise()
        mock.exercisesByCategory[.arms] = [exercise]

        let cache = MockCoordinatorCache()

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: cache,
            exerciseManagement: mock,
            workoutStorage: ws
        )
        let countBefore = vm.getExerciseCount(for: .arms)
        let exercisesBefore = vm.getExercises(for: .arms)

        let coordinator = cache.coordinator(for: .arms)
        coordinator.startTraining(for: exercise)
        try await waitUntil(timeout: .seconds(2)) { coordinator.isTrainingActive }

        coordinator.cancelTraining()
        try await waitUntil(timeout: .seconds(2)) { !coordinator.hasActiveSessions }

        #expect(vm.getExerciseCount(for: .arms)?.total == countBefore?.total)
        #expect(vm.getExerciseCount(for: .arms)?.active == countBefore?.active)
        #expect(vm.getExercises(for: .arms).count == exercisesBefore.count)
    }
}

// MARK: - Current Workout ID Exposure (T7a)

@MainActor
@Suite("MuscleCategorySelectionViewModel.currentWorkoutId")
struct CurrentWorkoutIdTests {

    @Test func returnsNilWhenNoWorkoutSelected() {
        let ws = MockWorkoutStorage()

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: MockExerciseManagement(),
            workoutStorage: ws
        )

        #expect(vm.currentWorkoutId == nil)
    }

    @Test func returnsIdOfSelectedWorkout() {
        let workout = Workout(name: "Test", selectedCategories: [.arms])
        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(workout)

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: MockExerciseManagement(),
            workoutStorage: ws
        )

        #expect(vm.currentWorkoutId == workout.id)
    }

    @Test func reflectsWorkoutSwitch() {
        let w1 = Workout(name: "W1", selectedCategories: [.arms])
        let w2 = Workout(name: "W2", selectedCategories: [.chest])
        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(w1)

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: MockExerciseManagement(),
            workoutStorage: ws
        )

        #expect(vm.currentWorkoutId == w1.id)

        ws.setCurrentWorkout(w2)
        #expect(vm.currentWorkoutId == w2.id)
    }
}

// MARK: - Workout Switch Refreshes Exercises (Phase 0d safety-net)

@Suite("workout switch refreshes exercises")
@MainActor
struct WorkoutSwitchRefreshTests {

    @Test func refreshExercisesPicksUpNewWorkoutData() {
        let mock = MockExerciseManagement()
        let armExercise = makeExercise(name: "Curl")
        mock.exercisesByCategory[.arms] = [armExercise]

        let w1 = Workout(name: "Push", selectedCategories: [.arms, .chest])
        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(w1)

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )

        #expect(vm.getExerciseCount(for: .arms)?.total == 1)
        #expect(vm.getExerciseCount(for: .chest)?.total == 0)

        let w2 = Workout(name: "Pull", selectedCategories: [.back])
        ws.setCurrentWorkout(w2)

        let chestExercise = makeExercise(name: "Bench")
        mock.exercisesByCategory[.chest] = [chestExercise]
        mock.exercisesByCategory[.arms] = []

        vm.refreshExercises()

        #expect(vm.getExerciseCount(for: .arms)?.total == 0)
        #expect(vm.getExerciseCount(for: .chest)?.total == 1)
    }
}
