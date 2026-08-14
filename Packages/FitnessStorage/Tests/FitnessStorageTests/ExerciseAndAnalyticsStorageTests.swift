import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@testable import FitnessStorageTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("Exercise & Analytics storage integration", .tags(.integration))
@MainActor
struct ExerciseAndAnalyticsStorageTests {
    private let container = TestHelpers.makeInMemoryContainer()

    @Test("Bilateral mode and side metadata survive storage reload")
    func bilateralMetadataRoundtrip() throws {
        let workoutStorage = TestHelpers.makeWorkoutStorageService(container: container)
        let workout = try #require(workoutStorage.workouts.first)
        let exerciseStorage = ExerciseStorageService(container: container)
        let analyticsStorage = AnalyticsStorageService(container: container)
        let exercise = TestHelpers.makeExercise(
            name: "Torso Rotation",
            sets: 2,
            category: .abs,
            executionMode: .bilateral
        )
        let progress = exercise.trainingSteps.map { step in
            SetProgress(
                status: .completedDone,
                currentReps: exercise.reps,
                weight: exercise.weight,
                side: step.side,
                logicalSetIndex: step.logicalSetIndex
            )
        }

        exerciseStorage.saveForWorkout([exercise], workoutId: workout.id, category: .abs)
        analyticsStorage.save(
            [AnalyticsEntry(exerciseId: exercise.id, date: .now, setProgress: progress)],
            for: exercise.id
        )

        let reloadedExercise = try #require(
            ExerciseStorageService(container: container).loadForWorkout(
                workoutId: workout.id,
                category: .abs
            ).first
        )
        let reloadedProgress = try #require(
            AnalyticsStorageService(container: container).load(for: exercise.id).first
        ).setProgress

        #expect(reloadedExercise.executionMode == .bilateral)
        #expect(reloadedProgress.map(\.side) == [.left, .right, .left, .right])
        #expect(reloadedProgress.map(\.logicalSetIndex) == [0, 0, 1, 1])
    }

    @Test func deletingWorkoutCascadesExercises() throws {
        let workoutStorage = TestHelpers.makeWorkoutStorageService(container: container)
        let workout = try workoutStorage.createWorkout(name: "To Delete")
        let exerciseStorage = ExerciseStorageService(container: container)
        exerciseStorage.saveForWorkout(
            [TestHelpers.makeExercise(name: "Curl", category: .arms)],
            workoutId: workout.id,
            category: .arms
        )

        workoutStorage.deleteWorkout(workout)

        #expect(
            exerciseStorage.loadForWorkout(
                workoutId: workout.id,
                category: .arms
            ).isEmpty
        )
    }
}
