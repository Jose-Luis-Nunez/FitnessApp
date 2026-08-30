import Testing
import Foundation
@testable import FitnessExercise
import FitnessCore
import FitnessTraining
import FitnessTestSupport

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

    var activeTrainings: [ActiveTrainingTarget] {
        coordinators.flatMap { group, coordinator in
            coordinator.activeExercises.values.map {
                ActiveTrainingTarget(exercise: $0, group: group)
            }
        }
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
@Suite("categories are always all cases", .tags(.fast))
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

}

// MARK: - Exercise Counts (with mocked ExerciseManaging)

@Suite("exercise counts", .tags(.fast))
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

    @Test func selectionAndActiveSetQueriesUseInjectedDependencies() {
        let cache = MockCoordinatorCache()
        let workoutStorage = MockWorkoutStorage()
        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: cache,
            exerciseManagement: MockExerciseManagement(),
            workoutStorage: workoutStorage
        )
        let workout = Workout(name: "Selected", selectedCategories: [.arms])
        let exercise = makeExercise(category: .arms)

        vm.selectWorkout(workout)
        #expect(workoutStorage.currentWorkout?.id == workout.id)
        #expect(!vm.hasActiveSetForCategory(.arms))

        cache.coordinator(for: .arms).startTraining(for: exercise)
        #expect(vm.hasActiveSetForCategory(.arms))
    }
}

// MARK: - Card ViewModel Cache

// MARK: - Reset All Exercises

@MainActor
private final class NoOpWorkoutExerciseOrderStorage: WorkoutExerciseOrderStoring {
    func recordStart(workoutId: UUID, exerciseId: UUID) {}
    func finalizeCycle(workoutId: UUID) {}
}

@Suite("resetAllExercises", .tags(.fast))
@MainActor
struct ResetAllExercisesTests {

    @Test func resetAllExercises_whenNoCurrentWorkout_doesNotMutateExercises() {
        let mock = MockExerciseManagement()
        let completed = makeExercise(isCompleted: true)
        mock.exercisesByCategory[.arms] = [completed]

        let cache = MockCoordinatorCache()
        let ws = MockWorkoutStorage()

        let resetUseCase = ResetAllExercisesUseCase(
            coordinatorCache: cache,
            exerciseManagement: mock,
            workoutStorage: ws,
            exerciseOrderStorage: NoOpWorkoutExerciseOrderStorage()
        )
        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: cache,
            exerciseManagement: mock,
            workoutStorage: ws,
            resetAllExercisesUseCase: resetUseCase
        )

        vm.resetAllExercises()

        #expect(mock.exercisesByCategory[.arms]?.first?.isCompleted == true)
    }

    @Test func resetsExercisesAndUpdatesCounts() {
        let mock = MockExerciseManagement()
        mock.exercisesByCategory[.arms] = [makeExercise(isCompleted: true)]

        let cache = MockCoordinatorCache()
        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let resetUseCase = ResetAllExercisesUseCase(
            coordinatorCache: cache,
            exerciseManagement: mock,
            workoutStorage: ws,
            exerciseOrderStorage: NoOpWorkoutExerciseOrderStorage()
        )
        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: cache,
            exerciseManagement: mock,
            workoutStorage: ws,
            resetAllExercisesUseCase: resetUseCase
        )
        #expect(vm.getExerciseCount(for: .arms)?.active == 0)

        vm.resetAllExercises()

        #expect(vm.getExerciseCount(for: .arms)?.active == 1)
    }
}

// MARK: - Find Category For Exercise

@Suite("findCategoryForExercise", .tags(.fast))
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

@Suite("exercise mutations", .tags(.fast))
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

    @Test func setExerciseActiveDeactivatesThroughUpdatePath() {
        let mock = MockExerciseManagement()
        let exercise = makeExercise()  // isActive defaults to true
        mock.exercisesByCategory[.arms] = [exercise]

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: mock,
            workoutStorage: ws
        )
        #expect(vm.getExercises(for: .arms).first?.isActive == true)

        vm.setExerciseActive(exercise, active: false, category: .arms)
        #expect(vm.getExercises(for: .arms).first?.isActive == false)

        // Reactivation flips it back.
        let deactivated = vm.getExercises(for: .arms).first!
        vm.setExerciseActive(deactivated, active: true, category: .arms)
        #expect(vm.getExercises(for: .arms).first?.isActive == true)
    }
}

// MARK: - Current Workout ID Exposure (T7a)

@MainActor
@Suite("MuscleCategorySelectionViewModel.currentWorkoutId", .tags(.fast))
struct CurrentWorkoutIdTests {

    @Test func tracksCurrentWorkoutAcrossNilSelectionAndSwitch() {
        let ws = MockWorkoutStorage()
        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            exerciseManagement: MockExerciseManagement(),
            workoutStorage: ws
        )
        #expect(vm.currentWorkoutId == nil)
        let w1 = Workout(name: "W1", selectedCategories: [.arms])
        let w2 = Workout(name: "W2", selectedCategories: [.chest])
        ws.setCurrentWorkout(w1)
        #expect(vm.currentWorkoutId == w1.id)

        ws.setCurrentWorkout(w2)
        #expect(vm.currentWorkoutId == w2.id)
    }
}
