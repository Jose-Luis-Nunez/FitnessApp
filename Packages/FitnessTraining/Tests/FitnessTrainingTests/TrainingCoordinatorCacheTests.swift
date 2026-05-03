import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessStorage
import FitnessTestSupport

@Suite("TrainingCoordinatorCache", .tags(.fast))
@MainActor
struct TrainingCoordinatorCacheTests {

    @Test func returnsSameCoordinatorForSameCategory() {
        let cache = TrainingCoordinatorCache(exerciseManagement: MockExerciseManagement())
        let first = cache.coordinator(for: .arms)
        let second = cache.coordinator(for: .arms)
        #expect(first === second)
    }

    @Test func returnsDifferentCoordinatorsForDifferentCategories() {
        let cache = TrainingCoordinatorCache(exerciseManagement: MockExerciseManagement())
        let arms = cache.coordinator(for: .arms)
        let chest = cache.coordinator(for: .chest)
        #expect(arms !== chest)
    }

    @Test func findCoordinatorForExerciseReturnsMatch() {
        let cache = TrainingCoordinatorCache(exerciseManagement: MockExerciseManagement())
        let coordinator = cache.coordinator(for: .chest)
        let exercise = Exercise(
            id: UUID(), name: "Bench", weight: 60, reps: 8, sets: 4,
            isCompleted: false, iconName: "defaultChestIcon", category: .chest
        )
        coordinator.startTraining(for: exercise)
        let result = cache.findCoordinator(for: exercise)
        #expect(result?.0 === coordinator)
        #expect(result?.1 == .chest)
    }

    @Test func findCoordinatorForExerciseReturnsNilWhenNotActive() {
        let cache = TrainingCoordinatorCache(exerciseManagement: MockExerciseManagement())
        _ = cache.coordinator(for: .arms)
        let exercise = Exercise(
            id: UUID(), name: "Curl", weight: 20, reps: 10, sets: 3,
            isCompleted: false, iconName: "defaultArmsIcon", category: .arms
        )
        #expect(cache.findCoordinator(for: exercise) == nil)
    }
}
