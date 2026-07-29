import Testing
import Foundation
import FitnessCore
@testable import FitnessExercise
import FitnessTraining
import FitnessTestSupport

@MainActor
private final class ResetOrderExerciseManagementSpy: ExerciseManaging {
    var onResetAll: (([MuscleCategoryGroup]) -> Void)?

    func updateExercise(_ updatedExercise: Exercise, category: MuscleCategoryGroup) {}
    func getExercises(for category: MuscleCategoryGroup) -> [Exercise] { [] }
    func addExercise(_ exercise: Exercise, category: MuscleCategoryGroup, atTop: Bool) {}
    func completeExercise(
        _ exercise: Exercise,
        category: MuscleCategoryGroup,
        setProgress: [SetProgress]
    ) {}
    func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {}
    func resetAllExercises(for categories: [MuscleCategoryGroup]) {
        onResetAll?(categories)
    }
    func getExerciseCount(
        for category: MuscleCategoryGroup
    ) -> (total: Int, active: Int) {
        (0, 0)
    }
    func getAllExerciseCounts(
        for categories: [MuscleCategoryGroup]
    ) -> [MuscleCategoryGroup: (total: Int, active: Int)] {
        [:]
    }
    func hasInactiveExercises(for categories: [MuscleCategoryGroup]) -> Bool {
        false
    }
}

@Suite("ResetAllExercisesUseCase", .tags(.fast))
@MainActor
struct ResetAllExercisesUseCaseTests {

    private func makeSUT() -> (
        ResetAllExercisesUseCase,
        MockExerciseManagement,
        TrainingCoordinatorCache,
        MockWorkoutStorage,
        WorkoutExerciseOrderStorageSpy
    ) {
        let mockExerciseManagement = MockExerciseManagement()
        let orderStorage = WorkoutExerciseOrderStorageSpy()
        let coordCache = TrainingCoordinatorCache(
            exerciseManagement: mockExerciseManagement,
            exerciseOrderStorage: orderStorage
        )
        let workoutStorage = MockWorkoutStorage()

        let sut = ResetAllExercisesUseCase(
            coordinatorCache: coordCache,
            exerciseManagement: mockExerciseManagement,
            workoutStorage: workoutStorage,
            exerciseOrderStorage: orderStorage
        )
        return (sut, mockExerciseManagement, coordCache, workoutStorage, orderStorage)
    }

    @Test func executeCancelsAllActiveSets() {
        let (sut, _, coordCache, _, _) = makeSUT()

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
        let (sut, mockExerciseManagement, _, _, _) = makeSUT()

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
        let (sut, mockExerciseManagement, _, _, _) = makeSUT()

        sut.execute(for: [])

        #expect(mockExerciseManagement.exercisesByCategory.isEmpty)
    }

    @Test func coordinatorSessionIsCancelledByResetAll() {
        let (sut, _, coordCache, _, _) = makeSUT()

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
        let (sut, _, coordCache, _, _) = makeSUT()

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
        let (sut, _, coordCache, _, _) = makeSUT()

        let exercise = FitnessTestSupport.makeExercise(name: "Curl", category: .arms)
        let coordinator = coordCache.coordinator(for: .arms)
        coordinator.startTraining(for: exercise)

        let activeVM = coordinator.activeSetViewModel
        #expect(activeVM.currentExercise != nil)

        sut.execute(for: [.arms])

        #expect(activeVM.timerSeconds == 0)
    }

    @Test func executeFinalizesThenCancelsSessionsBeforeResettingExercises() {
        var events: [String] = []
        let exerciseManagement = ResetOrderExerciseManagementSpy()
        let orderStorage = WorkoutExerciseOrderStorageSpy()
        let coordinatorCache = TrainingCoordinatorCache(
            exerciseManagement: exerciseManagement,
            exerciseOrderStorage: orderStorage
        )
        let workoutStorage = MockWorkoutStorage()
        let workout = Workout(name: "Pull")
        workoutStorage.currentWorkout = workout
        let armsCoordinator = coordinatorCache.coordinator(for: .arms)
        let chestCoordinator = coordinatorCache.coordinator(for: .chest)
        armsCoordinator.startTraining(
            for: FitnessTestSupport.makeExercise(category: .arms)
        )
        chestCoordinator.startTraining(
            for: FitnessTestSupport.makeExercise(category: .chest)
        )
        orderStorage.onFinalize = { workoutId in
            #expect(workoutId == workout.id)
            #expect(!armsCoordinator.activeSessions.isEmpty)
            #expect(!chestCoordinator.activeSessions.isEmpty)
            events.append("finalize")
        }
        exerciseManagement.onResetAll = { categories in
            #expect(categories == [.arms, .chest])
            #expect(armsCoordinator.activeSessions.isEmpty)
            #expect(chestCoordinator.activeSessions.isEmpty)
            events.append("reset")
        }
        let sut = ResetAllExercisesUseCase(
            coordinatorCache: coordinatorCache,
            exerciseManagement: exerciseManagement,
            workoutStorage: workoutStorage,
            exerciseOrderStorage: orderStorage
        )

        sut.execute(for: [.arms, .chest])

        #expect(orderStorage.finalizedWorkoutIds == [workout.id])
        #expect(events == ["finalize", "reset"])
    }
}
