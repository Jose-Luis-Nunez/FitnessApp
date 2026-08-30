import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessStorage
import FitnessAnalytics
import FitnessTestSupport

@Suite("TrainingCoordinatorCache", .tags(.fast))
@MainActor
struct TrainingCoordinatorCacheTests {

    @Test func returnsSameCoordinatorForSameCategory() {
        let cache = TrainingCoordinatorCache(
            exerciseManagement: MockExerciseManagement(),
            exerciseOrderStorage: WorkoutExerciseOrderStorageSpy()
        )
        let first = cache.coordinator(for: .arms)
        let second = cache.coordinator(for: .arms)
        #expect(first === second)
    }

    @Test func returnsDifferentCoordinatorsForDifferentCategories() {
        let cache = TrainingCoordinatorCache(
            exerciseManagement: MockExerciseManagement(),
            exerciseOrderStorage: WorkoutExerciseOrderStorageSpy()
        )
        let arms = cache.coordinator(for: .arms)
        let chest = cache.coordinator(for: .chest)
        #expect(arms !== chest)
    }

    @Test func everyCategoryCoordinatorUsesInjectedSharedAnalyticsViewModel() {
        let analyticsViewModel = AnalyticsViewModel(
            storageService: StubAnalyticsStorage()
        )
        let cache = TrainingCoordinatorCache(
            exerciseManagement: MockExerciseManagement(),
            exerciseOrderStorage: WorkoutExerciseOrderStorageSpy(),
            analyticsViewModel: analyticsViewModel
        )

        #expect(cache.coordinator(for: .arms).analyticsViewModel === analyticsViewModel)
        #expect(cache.coordinator(for: .chest).analyticsViewModel === analyticsViewModel)
    }

    @Test func findCoordinatorForExerciseReturnsMatch() {
        let cache = TrainingCoordinatorCache(
            exerciseManagement: MockExerciseManagement(),
            exerciseOrderStorage: WorkoutExerciseOrderStorageSpy()
        )
        let coordinator = cache.coordinator(for: .chest)
        let exercise = FitnessTestSupport.makeExercise(
            name: "Bench",
            weight: 60,
            reps: 8,
            sets: 4,
            category: .chest
        )
        coordinator.startTraining(for: exercise)
        let result = cache.findCoordinator(for: exercise)
        #expect(result?.0 === coordinator)
        #expect(result?.1 == .chest)
    }

    @Test func findCoordinatorForExerciseReturnsNilWhenNotActive() {
        let cache = TrainingCoordinatorCache(
            exerciseManagement: MockExerciseManagement(),
            exerciseOrderStorage: WorkoutExerciseOrderStorageSpy()
        )
        _ = cache.coordinator(for: .arms)
        let exercise = FitnessTestSupport.makeExercise()
        #expect(cache.findCoordinator(for: exercise) == nil)
    }

    @Test func freshWorkoutStartRecordsExactlyOnceAndResumeDoesNotRecordAgain() {
        let orderStorage = WorkoutExerciseOrderStorageSpy()
        let cache = TrainingCoordinatorCache(
            exerciseManagement: MockExerciseManagement(),
            exerciseOrderStorage: orderStorage
        )
        let coordinator = cache.coordinator(for: .arms)
        let workoutId = UUID()
        let exercise = FitnessTestSupport.makeExercise()

        let firstResult = coordinator.startTraining(
            for: exercise,
            workoutId: workoutId
        )
        let resumedResult = coordinator.startTraining(
            for: exercise,
            workoutId: workoutId
        )

        guard case .started? = firstResult else {
            Issue.record("Expected a fresh session")
            return
        }
        guard case .resumed? = resumedResult else {
            Issue.record("Expected the existing session to resume")
            return
        }
        #expect(orderStorage.recordedStarts.count == 1)
        #expect(orderStorage.recordedStarts.first?.workoutId == workoutId)
        #expect(orderStorage.recordedStarts.first?.exerciseId == exercise.id)
    }

    @Test func startWithoutWorkoutIdPreservesLegacyBehaviorWithoutRecording() {
        let orderStorage = WorkoutExerciseOrderStorageSpy()
        let cache = TrainingCoordinatorCache(
            exerciseManagement: MockExerciseManagement(),
            exerciseOrderStorage: orderStorage
        )
        let coordinator = cache.coordinator(for: .arms)
        let exercise = FitnessTestSupport.makeExercise()

        let result = coordinator.startTraining(for: exercise)

        guard case .started? = result else {
            Issue.record("Expected the legacy overload to start a session")
            return
        }
        #expect(coordinator.isExerciseInProgress(exercise.id))
        #expect(orderStorage.recordedStarts.isEmpty)
    }

    // MARK: - activeTrainings

    /// The mini bar pages through this list, so its order *is* the feature: the
    /// exercise the user last opened has to come first, across categories.
    @Test func activeTrainingsOrdersMostRecentlyFocusedFirstAcrossCategories() {
        let cache = TrainingCoordinatorCache(
            exerciseManagement: MockExerciseManagement(),
            exerciseOrderStorage: WorkoutExerciseOrderStorageSpy()
        )
        let arm = FitnessTestSupport.makeExercise(name: "Curl", category: .arms)
        let chest = FitnessTestSupport.makeExercise(name: "Bench", category: .chest)

        cache.coordinator(for: .arms).startTraining(for: arm)
        cache.coordinator(for: .chest).startTraining(for: chest)

        #expect(cache.activeTrainings.map(\.exercise.id) == [chest.id, arm.id])
        #expect(cache.activeTrainings.map(\.group) == [.chest, .arms])
    }

    /// Resuming re-focuses, which must move that exercise back to the front —
    /// this is what makes the bar reopen on whatever the user was just doing.
    @Test func activeTrainingsMovesResumedExerciseBackToTheFront() {
        let cache = TrainingCoordinatorCache(
            exerciseManagement: MockExerciseManagement(),
            exerciseOrderStorage: WorkoutExerciseOrderStorageSpy()
        )
        let arm = FitnessTestSupport.makeExercise(name: "Curl", category: .arms)
        let chest = FitnessTestSupport.makeExercise(name: "Bench", category: .chest)

        cache.coordinator(for: .arms).startTraining(for: arm)
        cache.coordinator(for: .chest).startTraining(for: chest)
        cache.coordinator(for: .arms).startTraining(for: arm)

        #expect(cache.activeTrainings.map(\.exercise.id) == [arm.id, chest.id])
    }

    /// Recency entries are never pruned, so a cancelled exercise still has one.
    /// Liveness has to come from the coordinator, otherwise the bar would offer
    /// a way back into a session that no longer exists.
    @Test func activeTrainingsDropsCancelledExerciseButKeepsTheRest() {
        let cache = TrainingCoordinatorCache(
            exerciseManagement: MockExerciseManagement(),
            exerciseOrderStorage: WorkoutExerciseOrderStorageSpy()
        )
        let arm = FitnessTestSupport.makeExercise(name: "Curl", category: .arms)
        let chest = FitnessTestSupport.makeExercise(name: "Bench", category: .chest)

        cache.coordinator(for: .arms).startTraining(for: arm)
        cache.coordinator(for: .chest).startTraining(for: chest)
        cache.coordinator(for: .chest).cancelTraining(for: chest.id)

        #expect(cache.activeTrainings.map(\.exercise.id) == [arm.id])
    }

    @Test func activeTrainingsIsEmptyWhenNothingRuns() {
        let cache = TrainingCoordinatorCache(
            exerciseManagement: MockExerciseManagement(),
            exerciseOrderStorage: WorkoutExerciseOrderStorageSpy()
        )
        _ = cache.coordinator(for: .arms)

        #expect(cache.activeTrainings.isEmpty)
    }
}
