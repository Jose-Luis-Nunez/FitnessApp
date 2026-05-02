import Testing
import Foundation
import FitnessCore
@testable import FitnessExercise
import FitnessTraining
import FitnessTestSupport
import Factory
import FitnessStorage

@Suite("ResetAllExercisesUseCase")
@MainActor
struct ResetAllExercisesUseCaseTests {

    private func makeSUT() -> (ResetAllExercisesUseCase, MockExerciseStorage, MockWorkoutStorage, SessionTrainingCache) {
        let mockExercise = MockExerciseStorage()
        let mockWorkout = MockWorkoutStorage()
        let mockAnalytics = MockAnalyticsStorage()
        let cache = SessionTrainingCache()

        Container.shared.reset()
        Container.shared.exerciseStorage.register { mockExercise }
        Container.shared.workoutStorage.register { mockWorkout }
        Container.shared.analyticsStorage.register { mockAnalytics }
        Container.shared.sessionTrainingCache.register { cache }
        Container.shared.exerciseManagement.register {
            ExerciseManagementService()
        }

        let sut = ResetAllExercisesUseCase()
        return (sut, mockExercise, mockWorkout, cache)
    }

    @Test func executeCancelsAllActiveSets() {
        let (sut, _, mockWorkout, cache) = makeSUT()
        let workout = Workout(name: "Test")
        mockWorkout.currentWorkout = workout
        mockWorkout.workouts = [workout]

        let vm = ActiveSetViewModel()
        let exercise = FitnessTestSupport.makeExercise(name: "Curl", category: .arms)
        vm.startSet(for: exercise, category: .arms)
        cache.activeSetVMs[.arms] = vm

        sut.execute(for: [.arms])

        #expect(vm.currentExercise == nil)
        #expect(vm.setProgress.isEmpty)
    }

    @Test func executeResetsCompletedExercisesAcrossCategories() {
        let (sut, mockExercise, mockWorkout, _) = makeSUT()
        let workout = Workout(name: "Test")
        mockWorkout.currentWorkout = workout
        mockWorkout.workouts = [workout]

        let armExercise = FitnessTestSupport.makeExercise(name: "Curl", isCompleted: true, category: .arms)
        let chestExercise = FitnessTestSupport.makeExercise(name: "Bench", isCompleted: true, category: .chest)
        mockExercise.exercisesByCategory[.arms] = [armExercise]
        mockExercise.exercisesByCategory[.chest] = [chestExercise]

        sut.execute(for: [.arms, .chest])

        let arms = mockExercise.exercisesByCategory[.arms] ?? []
        let chest = mockExercise.exercisesByCategory[.chest] ?? []
        #expect(arms.allSatisfy { !$0.isCompleted })
        #expect(chest.allSatisfy { !$0.isCompleted })
    }

    @Test func executeDoesNothingForEmptyCategories() {
        let (sut, mockExercise, _, _) = makeSUT()

        sut.execute(for: [])

        #expect(mockExercise.exercisesByCategory.isEmpty)
    }

    /// Safety-net: proves that cancelling active training sessions via
    /// coordinators works. After the planned rewiring from
    /// `SessionTrainingCache` to `TrainingCoordinatorCache`, this test
    /// must still pass (with adjusted wiring in `makeSUT`).
    @Test func coordinatorSessionIsCancelledByResetAll() async throws {
        let mockExercise = MockExerciseStorage()
        let mockWorkout = MockWorkoutStorage()
        let mockAnalytics = MockAnalyticsStorage()
        let coordCache = TrainingCoordinatorCache()
        let sessionCache = SessionTrainingCache()

        Container.shared.reset()
        Container.shared.exerciseStorage.register { mockExercise }
        Container.shared.workoutStorage.register { mockWorkout }
        Container.shared.analyticsStorage.register { mockAnalytics }
        Container.shared.sessionTrainingCache.register { sessionCache }
        Container.shared.exerciseManagement.register {
            ExerciseManagementService()
        }

        let workout = Workout(name: "Test")
        mockWorkout.currentWorkout = workout
        mockWorkout.workouts = [workout]

        let exercise = FitnessTestSupport.makeExercise(name: "Curl", category: .arms)
        let coordinator = coordCache.coordinator(for: .arms)
        coordinator.startTraining(for: exercise)

        try await waitUntil(timeout: .seconds(2)) { coordinator.isTrainingActive }
        #expect(coordinator.hasActiveSessions == true)

        // Mirror what production does: the coordinator's active VM should
        // also be registered in the session cache so the use case finds it.
        let activeVM = coordinator.activeSetViewModel
        sessionCache.activeSetVMs[.arms] = activeVM

        let sut = ResetAllExercisesUseCase()
        sut.execute(for: [.arms])

        #expect(activeVM.currentExercise == nil)
        #expect(activeVM.setProgress.isEmpty)
    }
}
