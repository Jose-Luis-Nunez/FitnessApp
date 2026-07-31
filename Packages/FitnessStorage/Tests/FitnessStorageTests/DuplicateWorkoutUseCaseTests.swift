import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("DuplicateWorkoutUseCase", .tags(.integration))
@MainActor
struct DuplicateWorkoutUseCaseTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func makeSUT() -> (DuplicateWorkoutUseCase, WorkoutStorageService) {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let es = ExerciseStorageService(container: container)
        let ws = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: es, analyticsStorage: TestHelpers.makeNoOpAnalyticsStoring())

        let sut = DuplicateWorkoutUseCase(workoutStorage: ws)
        return (sut, ws)
    }

    @Test func duplicateWorkoutCreatesNewWorkout() {
        let (sut, ws) = makeSUT()
        let original = ws.workouts.first!
        let countBefore = ws.workouts.count

        let duplicate = sut.execute(original)

        #expect(ws.workouts.count == countBefore + 1)
        #expect(duplicate.id != original.id)
    }

    @Test func duplicateWorkoutReturnsWorkoutWithNewId() {
        let (sut, ws) = makeSUT()
        let original = ws.workouts.first!

        let duplicate = sut.execute(original)

        #expect(duplicate.id != original.id)
        #expect(duplicate.name.contains(original.name))
    }

    @Test("Duplicate preserves bilateral mode with independent exercise IDs")
    func duplicatePreservesBilateralMode() throws {
        let (sut, ws) = makeSUT()
        let original = try #require(ws.workouts.first)
        let exerciseStorage = ExerciseStorageService(container: container)
        let bilateral = TestHelpers.makeExercise(
            name: "Torso Rotation",
            sets: 3,
            category: .abs,
            executionMode: .bilateral
        )
        exerciseStorage.saveForWorkout(
            [bilateral],
            workoutId: original.id,
            category: .abs
        )

        let duplicate = sut.execute(original)

        let originalExercise = try #require(
            exerciseStorage.loadForWorkout(
                workoutId: original.id,
                category: .abs
            ).first
        )
        let copiedExercise = try #require(
            exerciseStorage.loadForWorkout(
                workoutId: duplicate.id,
                category: .abs
            ).first
        )
        #expect(copiedExercise.executionMode == .bilateral)
        #expect(copiedExercise.id != originalExercise.id)
    }
}
