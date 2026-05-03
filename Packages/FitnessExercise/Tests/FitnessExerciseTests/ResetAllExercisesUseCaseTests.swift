import Testing
import Foundation
import FitnessCore
@testable import FitnessExercise
import FitnessTraining
import FitnessTestSupport

@Suite("ResetAllExercisesUseCase", .tags(.fast))
@MainActor
struct ResetAllExercisesUseCaseTests {

    private func makeSUT() -> (ResetAllExercisesUseCase, MockExerciseManagement, TrainingCoordinatorCache) {
        let mockExerciseManagement = MockExerciseManagement()
        let coordCache = TrainingCoordinatorCache(exerciseManagement: mockExerciseManagement)

        let sut = ResetAllExercisesUseCase(
            coordinatorCache: coordCache,
            exerciseManagement: mockExerciseManagement
        )
        return (sut, mockExerciseManagement, coordCache)
    }

    @Test func executeCancelsAllActiveSets() {
        let (sut, _, coordCache) = makeSUT()

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
        let (sut, mockExerciseManagement, _) = makeSUT()

        let armExercise = FitnessTestSupport.makeExercise(name: "Curl", isCompleted: true, category: .arms)
        let chestExercise = FitnessTestSupport.makeExercise(name: "Bench", isCompleted: true, category: .chest)
        mockExerciseManagement.exercisesByCategory[.arms] = [armExercise]
        mockExerciseManagement.exercisesByCategory[.chest] = [chestExercise]

        sut.execute(for: [.arms, .chest])

        let arms = mockExerciseManagement.exercisesByCategory[.arms] ?? []
        let chest = mockExerciseManagement.exercisesByCategory[.chest] ?? []
        #expect(arms.allSatisfy { !$0.isCompleted })
        #expect(chest.allSatisfy { !$0.isCompleted })
    }

    @Test func executeDoesNothingForEmptyCategories() {
        let (sut, mockExerciseManagement, _) = makeSUT()

        sut.execute(for: [])

        #expect(mockExerciseManagement.exercisesByCategory.isEmpty)
    }

    @Test func coordinatorSessionIsCancelledByResetAll() {
        let (sut, _, coordCache) = makeSUT()

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
        let (sut, _, coordCache) = makeSUT()

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
        let (sut, _, coordCache) = makeSUT()

        let exercise = FitnessTestSupport.makeExercise(name: "Curl", category: .arms)
        let coordinator = coordCache.coordinator(for: .arms)
        coordinator.startTraining(for: exercise)

        let activeVM = coordinator.activeSetViewModel
        #expect(activeVM.currentExercise != nil)

        sut.execute(for: [.arms])

        #expect(activeVM.timerSeconds == 0)
    }
}
