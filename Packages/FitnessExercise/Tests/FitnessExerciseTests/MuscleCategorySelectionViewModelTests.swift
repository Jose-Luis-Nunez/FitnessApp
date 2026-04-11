import Testing
import Foundation
@testable import FitnessExercise
import FitnessCore
import FitnessStorage
import FitnessTraining
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
            onExerciseReset: { _, _ in },
            activeSetViewModel: ActiveSetViewModel()
        )
        coordinators[group] = coordinator
        return coordinator
    }

    var activeCoordinator: TrainingCoordinator? {
        coordinators.values.first { $0.isTrainingActive }
    }

    func findCoordinator(for exercise: Exercise) -> (TrainingCoordinator, MuscleCategoryGroup)? {
        for (group, coordinator) in coordinators {
            if coordinator.currentExercise?.id == exercise.id {
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

// MARK: - Helpers

private func makeExercise(
    id: UUID = UUID(),
    name: String = "Curl",
    isCompleted: Bool = false,
    category: MuscleCategoryGroup = .arms
) -> Exercise {
    Exercise(
        id: id,
        name: name,
        weight: 20,
        reps: 10,
        sets: 3,
        isCompleted: isCompleted,
        iconName: "defaultArmsIcon",
        category: category
    )
}

@MainActor
private func registerMockExerciseManagement(_ mock: MockExerciseManagement) {
    Container.shared.exerciseManagement.register { mock }
}

// MARK: - Categories & Workout Observation

@Suite("categories loaded from workout")
@MainActor
struct CategoriesTests {

    init() {
        Container.shared.reset()
    }

    @Test func categoriesMatchWorkoutSelection() {
        let ws = Container.shared.workoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms, .chest]))

        let vm = MuscleCategorySelectionViewModel(coordinatorCache: MockCoordinatorCache())

        #expect(vm.categories.contains(.arms))
        #expect(vm.categories.contains(.chest))
        #expect(!vm.categories.contains(.legs))
    }

    @Test func categoriesEmptyWhenNoWorkout() {
        let ws = Container.shared.workoutStorage()
        ws.currentWorkout = nil

        let vm = MuscleCategorySelectionViewModel(coordinatorCache: MockCoordinatorCache())
        #expect(vm.categories.isEmpty)
    }

    @Test func categoriesUpdateReactivelyWhenWorkoutChanges() async throws {
        let ws = Container.shared.workoutStorage()
        ws.setCurrentWorkout(Workout(name: "W1", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(coordinatorCache: MockCoordinatorCache())
        #expect(vm.categories == [.arms])

        await Task.yield()
        try await Task.sleep(for: .milliseconds(50))

        ws.setCurrentWorkout(Workout(name: "W2", selectedCategories: [.chest, .legs]))

        await Task.yield()
        try await Task.sleep(for: .milliseconds(150))

        #expect(vm.categories.contains(.chest))
        #expect(vm.categories.contains(.legs))
        #expect(!vm.categories.contains(.arms))
    }
}

// MARK: - Exercise Counts (with mocked ExerciseManaging)

@Suite("exercise counts")
@MainActor
struct ExerciseCountsTests {

    init() {
        Container.shared.reset()
    }

    @Test func exerciseCountsReflectMockState() {
        let mock = MockExerciseManagement()
        mock.exercisesByCategory[.arms] = [makeExercise(), makeExercise(isCompleted: true)]
        registerMockExerciseManagement(mock)

        let ws = Container.shared.workoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(coordinatorCache: MockCoordinatorCache())

        let count = vm.getExerciseCount(for: .arms)
        #expect(count?.total == 2)
        #expect(count?.active == 1)
    }

    @Test func exerciseCountsUpdateAfterTrainingEnds() async throws {
        let mock = MockExerciseManagement()
        let exercise = makeExercise(isCompleted: false)
        mock.exercisesByCategory[.arms] = [exercise]
        registerMockExerciseManagement(mock)

        let ws = Container.shared.workoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let cache = MockCoordinatorCache()
        let vm = MuscleCategorySelectionViewModel(coordinatorCache: cache)
        #expect(vm.getExerciseCount(for: .arms)?.active == 1)

        await Task.yield()

        let coordinator = cache.coordinator(for: .arms)
        coordinator.startTraining(for: exercise)

        await Task.yield()
        try await Task.sleep(for: .milliseconds(50))

        // Simulate exercise completed externally
        var completed = exercise
        completed.isCompleted = true
        mock.exercisesByCategory[.arms] = [completed]

        for _ in 0..<exercise.sets { coordinator.completeSet() }
        coordinator.finishExercise()

        await Task.yield()
        try await Task.sleep(for: .milliseconds(100))

        #expect(vm.getExerciseCount(for: .arms)?.active == 0)
    }

    @Test func manualUpdateCountsPicksUpChange() {
        let mock = MockExerciseManagement()
        let exercise = makeExercise(isCompleted: false)
        mock.exercisesByCategory[.arms] = [exercise]
        registerMockExerciseManagement(mock)

        let ws = Container.shared.workoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(coordinatorCache: MockCoordinatorCache())
        #expect(vm.getExerciseCount(for: .arms)?.active == 1)

        var completed = exercise
        completed.isCompleted = true
        mock.exercisesByCategory[.arms] = [completed]

        // Without manual update, the cached count is stale
        // After explicit update, it reflects the change
        vm.updateExerciseCounts()
        #expect(vm.getExerciseCount(for: .arms)?.active == 0)
    }
}

// MARK: - Card ViewModel Cache

@Suite("card view model cache")
@MainActor
struct SelectionCardViewModelCacheTests {

    init() {
        Container.shared.reset()
    }

    @Test func returnsSameInstanceForSameExercise() {
        let ws = Container.shared.workoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(coordinatorCache: MockCoordinatorCache())
        let exercise = makeExercise()
        let first = vm.cardViewModel(for: exercise, category: .arms)
        let second = vm.cardViewModel(for: exercise, category: .arms)
        #expect(first === second)
    }

    @Test func returnsDifferentInstancesForDifferentExercises() {
        let ws = Container.shared.workoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(coordinatorCache: MockCoordinatorCache())
        let ex1 = makeExercise(name: "Curl")
        let ex2 = makeExercise(name: "Press")
        #expect(vm.cardViewModel(for: ex1, category: .arms) !== vm.cardViewModel(for: ex2, category: .arms))
    }
}

// MARK: - Reset All Exercises

@Suite("resetAllExercises")
@MainActor
struct ResetAllExercisesTests {

    init() {
        Container.shared.reset()
    }

    @Test func doesNothingWithoutWorkout() {
        let ws = Container.shared.workoutStorage()
        ws.currentWorkout = nil

        let vm = MuscleCategorySelectionViewModel(coordinatorCache: MockCoordinatorCache())
        vm.resetAllExercises()
    }

    @Test func resetsExercisesAndUpdatesCounts() {
        let mock = MockExerciseManagement()
        mock.exercisesByCategory[.arms] = [makeExercise(isCompleted: true)]
        registerMockExerciseManagement(mock)

        let ws = Container.shared.workoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(coordinatorCache: MockCoordinatorCache())
        #expect(vm.getExerciseCount(for: .arms)?.active == 0)

        vm.resetAllExercises()

        #expect(vm.getExerciseCount(for: .arms)?.active == 1)
    }
}

// MARK: - Find Category For Exercise

@Suite("findCategoryForExercise")
@MainActor
struct FindCategoryTests {

    init() {
        Container.shared.reset()
    }

    @Test func findsCorrectCategory() {
        let mock = MockExerciseManagement()
        let exercise = makeExercise()
        mock.exercisesByCategory[.arms] = [exercise]
        registerMockExerciseManagement(mock)

        let ws = Container.shared.workoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms, .chest]))

        let vm = MuscleCategorySelectionViewModel(coordinatorCache: MockCoordinatorCache())
        #expect(vm.findCategoryForExercise(exercise) == .arms)
    }

    @Test func returnsNilForUnknownExercise() {
        let mock = MockExerciseManagement()
        registerMockExerciseManagement(mock)

        let ws = Container.shared.workoutStorage()
        ws.setCurrentWorkout(Workout(name: "Test", selectedCategories: [.arms]))

        let vm = MuscleCategorySelectionViewModel(coordinatorCache: MockCoordinatorCache())
        #expect(vm.findCategoryForExercise(makeExercise()) == nil)
    }
}
