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
}
