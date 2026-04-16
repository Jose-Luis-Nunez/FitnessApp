import Testing
import Foundation
import Observation
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

@MainActor
private final class MockExerciseManagement: ExerciseManaging {
    var exercisesByCategory: [MuscleCategoryGroup: [Exercise]] = [:]

    func updateExercise(_ updatedExercise: Exercise, category: MuscleCategoryGroup) {
        guard var exercises = exercisesByCategory[category],
              let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) else { return }
        exercises[index] = updatedExercise
        exercisesByCategory[category] = exercises
    }

    func getExercises(for category: MuscleCategoryGroup) -> [Exercise] {
        exercisesByCategory[category] ?? []
    }

    func addExercise(_ exercise: Exercise, category: MuscleCategoryGroup, atTop: Bool) {
        var exercises = exercisesByCategory[category] ?? []
        if atTop { exercises.insert(exercise, at: 0) } else { exercises.append(exercise) }
        exercisesByCategory[category] = exercises
    }

    func completeExercise(_ exercise: Exercise, category: MuscleCategoryGroup, setProgress: [SetProgress]) {
        var updated = exercise
        updated.isCompleted = true
        updateExercise(updated, category: category)
    }

    func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        var updated = exercise
        updated.isCompleted = false
        updateExercise(updated, category: category)
    }

    func resetAllExercises(for categories: [MuscleCategoryGroup]) {
        for category in categories {
            let exercises = exercisesByCategory[category] ?? []
            exercisesByCategory[category] = exercises.map {
                var e = $0; e.isCompleted = false; return e
            }
        }
    }

    func getExerciseCount(for category: MuscleCategoryGroup) -> (total: Int, active: Int) {
        let exercises = exercisesByCategory[category] ?? []
        return (total: exercises.count, active: exercises.filter { !$0.isCompleted }.count)
    }

    func getAllExerciseCounts(for categories: [MuscleCategoryGroup]) -> [MuscleCategoryGroup: (total: Int, active: Int)] {
        var result: [MuscleCategoryGroup: (total: Int, active: Int)] = [:]
        for cat in categories { result[cat] = getExerciseCount(for: cat) }
        return result
    }

    func hasInactiveExercises(for categories: [MuscleCategoryGroup]) -> Bool {
        categories.contains { cat in
            (exercisesByCategory[cat] ?? []).contains { $0.isCompleted }
        }
    }
}

// MARK: - Observable Mock Workout Storage (for reactive tests)

@Observable
@MainActor
private final class ObservableMockWorkoutStorage: WorkoutStoring {
    var workouts: [Workout] = []
    var currentWorkout: Workout?
    var defaultWorkout: Workout?

    func createWorkout(name: String, selectedCategories: Set<MuscleCategoryGroup>) -> Workout {
        let workout = Workout(name: name, selectedCategories: selectedCategories)
        workouts.append(workout)
        return workout
    }

    func duplicateWorkout(_ workout: Workout) -> Workout { workout }
    func deleteWorkout(_ workout: Workout) {}
    func updateWorkout(_ workout: Workout) {}

    func setCurrentWorkout(_ workout: Workout) { currentWorkout = workout }
    func setAsDefaultWorkout(_ workout: Workout) { defaultWorkout = workout }
    func removeAsDefaultWorkout() { defaultWorkout = nil }
    func renameWorkout(_ workout: Workout, newName: String) {}
}

// MARK: - Categories & Workout Observation

@Suite("categories loaded from workout")
@MainActor
struct CategoriesTests {

    @Test func categoriesMatchWorkoutSelection() {
        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms, .chest]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            workoutStorage: ws
        )

        #expect(vm.categories.contains(.arms))
        #expect(vm.categories.contains(.chest))
        #expect(!vm.categories.contains(.legs))
    }

    @Test func categoriesEmptyWhenNoWorkout() {
        let ws = MockWorkoutStorage()

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            workoutStorage: ws
        )
        #expect(vm.categories.isEmpty)
    }

    @Test func categoriesUpdateReactivelyWhenWorkoutChanges() async throws {
        let ws = ObservableMockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "W1", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            workoutStorage: ws
        )
        #expect(vm.categories == [.arms])

        try await Task.sleep(for: .milliseconds(50))

        ws.setCurrentWorkout(Workout(name: "W2", selectedCategories: [.chest, .legs]))

        try await waitUntil(timeout: .seconds(1)) { vm.categories.contains(.chest) }

        #expect(vm.categories.contains(.chest))
        #expect(vm.categories.contains(.legs))
        #expect(!vm.categories.contains(.arms))
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

        try await waitUntil(timeout: .seconds(2)) { vm.getExerciseCount(for: .arms)?.active == 0 }

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

@Suite("card view model cache")
@MainActor
struct SelectionCardViewModelCacheTests {

    @Test func returnsSameInstanceForSameExercise() {
        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            workoutStorage: ws
        )
        let exercise = makeExercise()
        let first = vm.cardViewModel(for: exercise, category: .arms)
        let second = vm.cardViewModel(for: exercise, category: .arms)
        #expect(first === second)
    }

    @Test func returnsDifferentInstancesForDifferentExercises() {
        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            workoutStorage: ws
        )
        let ex1 = makeExercise(name: "Curl")
        let ex2 = makeExercise(name: "Press")
        #expect(vm.cardViewModel(for: ex1, category: .arms) !== vm.cardViewModel(for: ex2, category: .arms))
    }
}

// MARK: - Reset All Exercises

@Suite("resetAllExercises")
@MainActor
struct ResetAllExercisesTests {

    @Test func doesNothingWithoutWorkout() {
        let ws = MockWorkoutStorage()

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: MockCoordinatorCache(),
            workoutStorage: ws
        )
        vm.resetAllExercises()
    }

    @Test func resetsExercisesAndUpdatesCounts() {
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

// MARK: - Coordinator Completion Integration (Phase 1b)

@Suite("coordinator completion integration")
@MainActor
struct CoordinatorCompletionIntegrationTests {

    private func makeIntegrationSetup(
        exercise: Exercise = makeExercise(sets: 3)
    ) -> (vm: MuscleCategorySelectionViewModel, coordinator: TrainingCoordinator, mock: MockExerciseManagement) {
        let mock = MockExerciseManagement()
        mock.exercisesByCategory[.arms] = [exercise]

        let cache = MockCoordinatorCache()

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: cache,
            exerciseManagement: mock,
            workoutStorage: ws
        )
        let coordinator = cache.coordinator(for: .arms)

        return (vm, coordinator, mock)
    }

    @Test func completionFlowUpdatesCardVM() async throws {
        let exercise = makeExercise(sets: 3)
        let (vm, coordinator, mock) = makeIntegrationSetup(exercise: exercise)

        let cardVM = vm.cardViewModel(for: exercise, category: .arms)
        #expect(!cardVM.exercise.isCompleted)

        await Task.yield()

        coordinator.startTraining(for: exercise)
        try await waitUntil(timeout: .seconds(2)) { coordinator.isTrainingActive }

        for _ in 0..<exercise.sets { coordinator.completeSet() }

        var completed = exercise
        completed.isCompleted = true
        mock.exercisesByCategory[.arms] = [completed]

        coordinator.finishExercise()

        try await waitUntil(timeout: .seconds(2)) { cardVM.exercise.isCompleted }
        #expect(cardVM.exercise.isCompleted)
    }

    @Test func completionFlowUpdatesExerciseCounts() async throws {
        let exercise = makeExercise(sets: 3)
        let (vm, coordinator, mock) = makeIntegrationSetup(exercise: exercise)
        #expect(vm.getExerciseCount(for: .arms)?.active == 1)

        await Task.yield()

        coordinator.startTraining(for: exercise)
        try await waitUntil(timeout: .seconds(2)) { coordinator.isTrainingActive }

        for _ in 0..<exercise.sets { coordinator.completeSet() }

        var completed = exercise
        completed.isCompleted = true
        mock.exercisesByCategory[.arms] = [completed]

        coordinator.finishExercise()

        try await waitUntil(timeout: .seconds(2)) { vm.getExerciseCount(for: .arms)?.active == 0 }
        #expect(vm.getExerciseCount(for: .arms)?.active == 0)
    }

    @Test func completionFlowWritesBackToStorage() async throws {
        let exercise = makeExercise(sets: 3)
        let mock = MockExerciseManagement()
        mock.exercisesByCategory[.arms] = [exercise]

        let cache = MockCoordinatorCache()

        let ws = MockWorkoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(
            coordinatorCache: cache,
            exerciseManagement: mock,
            workoutStorage: ws
        )
        let coordinator = cache.coordinator(for: .arms)

        await Task.yield()

        coordinator.startTraining(for: exercise)
        try await waitUntil(timeout: .seconds(2)) { coordinator.isTrainingActive }

        for _ in 0..<exercise.sets { coordinator.completeSet() }

        var completed = exercise
        completed.isCompleted = true
        mock.exercisesByCategory[.arms] = [completed]

        coordinator.finishExercise()

        try await waitUntil(timeout: .seconds(2)) { vm.getExerciseCount(for: .arms)?.active == 0 }

        let storedExercises = mock.exercisesByCategory[.arms] ?? []
        #expect(storedExercises.first?.isCompleted == true)
    }

    @Test func partialCompletionDoesNotMarkCompleted() async throws {
        let exercise = makeExercise(sets: 3)
        let (vm, coordinator, _) = makeIntegrationSetup(exercise: exercise)

        let cardVM = vm.cardViewModel(for: exercise, category: .arms)

        coordinator.startTraining(for: exercise)
        try await waitUntil(timeout: .seconds(2)) { coordinator.isTrainingActive }

        coordinator.completeSet()
        coordinator.finishExercise()

        try await Task.sleep(for: .milliseconds(200))
        #expect(!cardVM.exercise.isCompleted)
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
