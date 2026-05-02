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

    private func makeSUT() -> (ResetAllExercisesUseCase, MockExerciseStorage, MockWorkoutStorage, TrainingCoordinatorCache) {
        let mockExercise = MockExerciseStorage()
        let mockWorkout = MockWorkoutStorage()
        let mockAnalytics = MockAnalyticsStorage()
        let coordCache = TrainingCoordinatorCache()

        Container.shared.reset()
        Container.shared.exerciseStorage.register { mockExercise }
        Container.shared.workoutStorage.register { mockWorkout }
        Container.shared.analyticsStorage.register { mockAnalytics }
        Container.shared.trainingCoordinatorCache.register { coordCache }
        Container.shared.exerciseManagement.register {
            ExerciseManagementService()
        }

        let sut = ResetAllExercisesUseCase()
        return (sut, mockExercise, mockWorkout, coordCache)
    }

    @Test func executeCancelsAllActiveSets() {
        let (sut, _, mockWorkout, coordCache) = makeSUT()
        let workout = Workout(name: "Test")
        mockWorkout.currentWorkout = workout
        mockWorkout.workouts = [workout]

        let exercise = FitnessTestSupport.makeExercise(name: "Curl", category: .arms)
        let coordinator = coordCache.coordinator(for: .arms)
        coordinator.startTraining(for: exercise)

        let activeVM = coordinator.activeSetViewModel
        #expect(activeVM.currentExercise != nil)

        sut.execute(for: [.arms])

        #expect(coordinator.activeSessions.isEmpty)
        #expect(activeVM.currentExercise == nil)
        #expect(activeVM.setProgress.isEmpty)
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

    @Test func coordinatorSessionIsCancelledByResetAll() {
        let (sut, _, mockWorkout, coordCache) = makeSUT()
        let workout = Workout(name: "Test")
        mockWorkout.currentWorkout = workout
        mockWorkout.workouts = [workout]

        let exercise = FitnessTestSupport.makeExercise(name: "Curl", category: .arms)
        let coordinator = coordCache.coordinator(for: .arms)
        coordinator.startTraining(for: exercise)

        #expect(coordinator.hasActiveSessions == true)

        let activeVM = coordinator.activeSetViewModel

        sut.execute(for: [.arms])

        #expect(activeVM.currentExercise == nil)
        #expect(activeVM.setProgress.isEmpty)
        #expect(coordinator.activeSessions.isEmpty)
    }

    @Test func executeCancelsActiveSessionsAcrossMultipleCategories() {
        let (sut, _, mockWorkout, coordCache) = makeSUT()
        let workout = Workout(name: "Test")
        mockWorkout.currentWorkout = workout
        mockWorkout.workouts = [workout]

        let armExercise = FitnessTestSupport.makeExercise(name: "Curl", category: .arms)
        let chestExercise = FitnessTestSupport.makeExercise(name: "Bench", category: .chest)

        let armsCoord = coordCache.coordinator(for: .arms)
        let chestCoord = coordCache.coordinator(for: .chest)
        armsCoord.startTraining(for: armExercise)
        chestCoord.startTraining(for: chestExercise)

        #expect(armsCoord.hasActiveSessions == true)
        #expect(chestCoord.hasActiveSessions == true)

        sut.execute(for: [.arms, .chest])

        #expect(armsCoord.activeSessions.isEmpty)
        #expect(chestCoord.activeSessions.isEmpty)
    }

    @Test func timerIsZeroOnCancelledVMAfterResetAll() {
        let (sut, _, mockWorkout, coordCache) = makeSUT()
        let workout = Workout(name: "Test")
        mockWorkout.currentWorkout = workout
        mockWorkout.workouts = [workout]

        let exercise = FitnessTestSupport.makeExercise(name: "Curl", category: .arms)
        let coordinator = coordCache.coordinator(for: .arms)
        coordinator.startTraining(for: exercise)

        let activeVM = coordinator.activeSetViewModel
        #expect(activeVM.currentExercise != nil)

        sut.execute(for: [.arms])

        #expect(activeVM.timerSeconds == 0)
    }
}
