import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage
import Factory

@Suite("DeleteWorkoutUseCase", .serialized, .tags(.integration))
@MainActor
struct DeleteWorkoutUseCaseTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func makeSUT() -> (DeleteWorkoutUseCase, WorkoutStorageService, ExerciseStorageService) {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let es = ExerciseStorageService(container: container)
        let ws = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: es)

        Container.shared.reset()
        Container.shared.workoutStorage.register { ws }
        Container.shared.exerciseStorage.register { es }

        let sut = DeleteWorkoutUseCase()
        return (sut, ws, es)
    }

    @Test func deleteWorkoutRemovesWorkout() {
        let (sut, ws, _) = makeSUT()
        let workout = ws.createWorkout(name: "To Delete")
        let initialCount = ws.workouts.count

        sut.execute(workout)

        #expect(ws.workouts.count == initialCount - 1)
        #expect(!ws.workouts.contains { $0.id == workout.id })
    }

    @Test func deleteWorkoutCleansUpExercisesForSelectedCategories() {
        let (sut, ws, es) = makeSUT()
        let workout = ws.createWorkout(name: "With Exercises", selectedCategories: [.arms, .chest])

        let armExercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        let chestExercise = TestHelpers.makeExercise(name: "Bench", category: .chest)
        es.saveForWorkout([armExercise], workoutId: workout.id, category: .arms)
        es.saveForWorkout([chestExercise], workoutId: workout.id, category: .chest)

        sut.execute(workout)

        #expect(es.loadForWorkout(workoutId: workout.id, category: .arms).isEmpty)
        #expect(es.loadForWorkout(workoutId: workout.id, category: .chest).isEmpty)
    }

    @Test func deleteWorkoutDoesNotAffectOtherWorkouts() {
        let (sut, ws, es) = makeSUT()
        let keepWorkout = ws.workouts.first!
        let deleteWorkout = ws.createWorkout(name: "To Delete")

        let exercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        es.saveForWorkout([exercise], workoutId: keepWorkout.id, category: .arms)

        sut.execute(deleteWorkout)

        #expect(es.loadForWorkout(workoutId: keepWorkout.id, category: .arms).count == 1)
    }
}
