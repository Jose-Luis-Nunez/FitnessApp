import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("ExerciseManagementService", .tags(.integration))
@MainActor
struct ExerciseManagementServiceTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func makeSUT() -> (ExerciseManagementService, WorkoutStorageService, ExerciseStorageService, AnalyticsStorageService) {
        let stack = TestHelpers.makeStorageStack(container: container)
        return (stack.management, stack.workoutStorage, stack.exerciseStorage, stack.analyticsStorage)
    }

    // MARK: - getExercises

    @Test func getExercisesReturnsEmptyForNoExercises() {
        let (sut, _, _, _) = makeSUT()
        let exercises = sut.getExercises(for: .arms)
        #expect(exercises.isEmpty)
    }

    @Test func getExercisesReturnsAddedExercises() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        let exercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        es.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        let loaded = sut.getExercises(for: .arms)
        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "Curl")
    }

    // MARK: - addExercise

    @Test func addExerciseAppendsToEnd() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        let existing = TestHelpers.makeExercise(name: "Existing", category: .arms)
        es.saveForWorkout([existing], workoutId: workout.id, category: .arms)

        let newExercise = TestHelpers.makeExercise(name: "New", category: .arms)
        sut.addExercise(newExercise, category: .arms, atTop: false)

        let exercises = sut.getExercises(for: .arms)
        #expect(exercises.count == 2)
        #expect(exercises.last?.name == "New")
    }

    @Test func addExerciseInsertsAtTopWhenFlagged() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        let existing = TestHelpers.makeExercise(name: "Existing", category: .arms)
        es.saveForWorkout([existing], workoutId: workout.id, category: .arms)

        let newExercise = TestHelpers.makeExercise(name: "Top", category: .arms)
        sut.addExercise(newExercise, category: .arms, atTop: true)

        let exercises = sut.getExercises(for: .arms)
        #expect(exercises.count == 2)
        #expect(exercises.first?.name == "Top")
    }

    // MARK: - updateExercise

    @Test func updateExerciseModifiesExistingExercise() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        let exercise = TestHelpers.makeExercise(name: "Curl", weight: 10, category: .arms)
        es.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        var updated = exercise
        updated.weight = 20
        sut.updateExercise(updated, category: .arms)

        let exercises = sut.getExercises(for: .arms)
        #expect(exercises.first?.weight == 20)
    }

    @Test func updateExerciseDoesNothingWhenIdNotFound() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        let exercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        es.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        let unrelated = TestHelpers.makeExercise(name: "Ghost", category: .arms)
        sut.updateExercise(unrelated, category: .arms)

        let exercises = sut.getExercises(for: .arms)
        #expect(exercises.count == 1)
        #expect(exercises.first?.name == "Curl")
    }

    // MARK: - completeExercise

    @Test func completeExerciseSetsCompletedAndSavesAnalytics() {
        let (sut, ws, es, as_) = makeSUT()
        let workout = ws.workouts.first!

        let exercise = TestHelpers.makeExercise(name: "Bench", category: .chest)
        es.saveForWorkout([exercise], workoutId: workout.id, category: .chest)

        let progress = [SetProgress(status: .completedDone, currentReps: 10, weight: 60)]
        sut.completeExercise(exercise, category: .chest, setProgress: progress)

        let exercises = sut.getExercises(for: .chest)
        #expect(exercises.first?.isCompleted == true)

        let analytics = as_.load(for: exercise.id)
        #expect(analytics.count == 1)
        #expect(analytics.first?.setProgress.count == 1)
    }

    @Test func completeExerciseDoesNotSaveAnalyticsForEmptyProgress() {
        let (sut, ws, es, as_) = makeSUT()
        let workout = ws.workouts.first!

        let exercise = TestHelpers.makeExercise(name: "Bench", category: .chest)
        es.saveForWorkout([exercise], workoutId: workout.id, category: .chest)

        sut.completeExercise(exercise, category: .chest, setProgress: [])

        let analytics = as_.load(for: exercise.id)
        #expect(analytics.isEmpty)
    }

    // MARK: - resetExercise

    @Test func resetExerciseClearsCompletedFlag() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        let exercise = TestHelpers.makeExercise(name: "Curl", isCompleted: true, category: .arms)
        es.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        sut.resetExercise(exercise, category: .arms)

        let exercises = sut.getExercises(for: .arms)
        #expect(exercises.first?.isCompleted == false)
    }

    // MARK: - resetAllExercises

    @Test func resetAllExercisesClearsCompletionAcrossCategories() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        let arm = TestHelpers.makeExercise(name: "Curl", isCompleted: true, category: .arms)
        let chest = TestHelpers.makeExercise(name: "Bench", isCompleted: true, category: .chest)
        es.saveForWorkout([arm], workoutId: workout.id, category: .arms)
        es.saveForWorkout([chest], workoutId: workout.id, category: .chest)

        sut.resetAllExercises(for: [.arms, .chest])

        let armExercises = sut.getExercises(for: .arms)
        let chestExercises = sut.getExercises(for: .chest)
        #expect(armExercises.allSatisfy { !$0.isCompleted })
        #expect(chestExercises.allSatisfy { !$0.isCompleted })
    }

    // MARK: - getExerciseCount

    @Test func getExerciseCountReturnsTotalAndActiveCount() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        let exercises = [
            TestHelpers.makeExercise(name: "Curl", isCompleted: false, category: .arms),
            TestHelpers.makeExercise(name: "Tricep", isCompleted: true, category: .arms),
            TestHelpers.makeExercise(name: "Hammer", isCompleted: false, category: .arms)
        ]
        es.saveForWorkout(exercises, workoutId: workout.id, category: .arms)

        let count = sut.getExerciseCount(for: .arms)
        #expect(count.total == 3)
        #expect(count.active == 2)
    }

    // MARK: - getAllExerciseCounts

    @Test func getAllExerciseCountsReturnsPerCategory() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        es.saveForWorkout(
            [TestHelpers.makeExercise(name: "Curl", category: .arms)],
            workoutId: workout.id, category: .arms
        )
        es.saveForWorkout(
            [TestHelpers.makeExercise(name: "Bench", category: .chest),
             TestHelpers.makeExercise(name: "Fly", category: .chest)],
            workoutId: workout.id, category: .chest
        )

        let counts = sut.getAllExerciseCounts(for: [.arms, .chest, .legs])
        #expect(counts[.arms]?.total == 1)
        #expect(counts[.chest]?.total == 2)
        #expect(counts[.legs]?.total == 0)
    }

    // MARK: - hasInactiveExercises

    @Test func hasInactiveExercisesReturnsTrueWhenCompleted() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        es.saveForWorkout(
            [TestHelpers.makeExercise(name: "Curl", isCompleted: true, category: .arms)],
            workoutId: workout.id, category: .arms
        )

        #expect(sut.hasInactiveExercises(for: [.arms]) == true)
    }

    @Test func hasInactiveExercisesReturnsFalseWhenAllActive() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        es.saveForWorkout(
            [TestHelpers.makeExercise(name: "Curl", isCompleted: false, category: .arms)],
            workoutId: workout.id, category: .arms
        )

        #expect(sut.hasInactiveExercises(for: [.arms]) == false)
    }

    // MARK: - No Current Workout

    @Test func addExerciseDoesNothingWithoutCurrentWorkout() {
        let ws = MockWorkoutStorage()
        let es = MockExerciseStorage()
        let as_ = StubAnalyticsStorage()

        let sut = ExerciseManagementService(
            exerciseStorage: es,
            analyticsStorage: as_,
            workoutStorage: ws
        )
        let exercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        sut.addExercise(exercise, category: .arms, atTop: false)

        #expect(sut.getExercises(for: .arms).isEmpty)
    }
}
