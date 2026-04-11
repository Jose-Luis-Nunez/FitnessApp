import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessAnalytics
import Factory

// MARK: - Helpers

private func makeExercise(
    id: UUID = UUID(),
    sets: Int = 3,
    isCompleted: Bool = false
) -> Exercise {
    Exercise(
        id: id,
        name: "Curl",
        weight: 20,
        reps: 10,
        sets: sets,
        isCompleted: isCompleted,
        iconName: "defaultArmsIcon",
        category: .arms
    )
}

@MainActor
private final class MockAnalyticsStorageForCoord: AnalyticsStoring {
    func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {}
    func load(for exerciseId: UUID) -> [AnalyticsEntry] { [] }
}

@MainActor
private func makeCoordinator(
    onExerciseUpdate: @escaping (Exercise, MuscleCategoryGroup) -> Void = { _, _ in },
    onExerciseReset: @escaping (Exercise, MuscleCategoryGroup) -> Void = { _, _ in }
) -> TrainingCoordinator {
    Container.shared.reset()
    let coordinator = TrainingCoordinator(
        findCategory: { _ in .arms },
        onExerciseUpdate: onExerciseUpdate,
        onExerciseReset: onExerciseReset,
        analyticsViewModel: AnalyticsViewModel(storageService: MockAnalyticsStorageForCoord())
    )
    return coordinator
}

// MARK: - finishExercise

@Suite("finishExercise")
@MainActor
struct FinishExerciseTests {

    @Test func setsCurrentExerciseToNilAndIsTrainingActiveToFalse() {
        let coordinator = makeCoordinator()

        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)
        #expect(coordinator.currentExercise != nil)
        #expect(coordinator.isTrainingActive == true)

        for _ in 0..<exercise.sets {
            coordinator.completeSet()
        }

        coordinator.finishExercise()

        #expect(coordinator.currentExercise == nil)
        #expect(coordinator.isTrainingActive == false)
    }

    @Test func callsOnExerciseUpdateWithIsCompletedTrue() {
        var receivedExercise: Exercise?
        var receivedCategory: MuscleCategoryGroup?

        let coordinator = makeCoordinator(
            onExerciseUpdate: { ex, cat in
                receivedExercise = ex
                receivedCategory = cat
            }
        )

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)

        for _ in 0..<3 {
            coordinator.completeSet()
        }

        coordinator.finishExercise()

        #expect(receivedExercise?.isCompleted == true)
        #expect(receivedCategory == .arms)
    }

    @Test func setsLastCompletedExerciseWhenAllSetsFinished() {
        let coordinator = makeCoordinator()

        let exercise = makeExercise(sets: 2)
        coordinator.startTraining(for: exercise)

        for _ in 0..<2 { coordinator.completeSet() }
        coordinator.finishExercise()

        #expect(coordinator.lastCompletedExercise != nil)
        #expect(coordinator.lastCompletedExercise?.id == exercise.id)
        #expect(coordinator.lastCompletedExercise?.isCompleted == true)
    }

    @Test func doesNotSetLastCompletedWhenNotAllSetsFinished() {
        let coordinator = makeCoordinator()

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)
        coordinator.completeSet()
        coordinator.finishExercise()

        #expect(coordinator.lastCompletedExercise == nil)
    }

    @Test func doesNotMarkCompletedWhenLastSetNotFinished() {
        var receivedExercise: Exercise?

        let coordinator = makeCoordinator(
            onExerciseUpdate: { ex, _ in receivedExercise = ex }
        )

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)
        coordinator.completeSet()

        coordinator.finishExercise()

        #expect(receivedExercise?.isCompleted != true)
    }

    @Test func resetsActiveSetViewModelState() {
        let coordinator = makeCoordinator()

        let exercise = makeExercise(sets: 1)
        coordinator.startTraining(for: exercise)
        let vm = coordinator.activeSetViewModel
        coordinator.completeSet()
        coordinator.finishExercise()

        #expect(vm.currentExercise == nil)
        #expect(vm.setProgress.isEmpty)
        #expect(vm.isSetInProgress == false)
    }

    @Test func finishSpecificExerciseById() {
        let coordinator = makeCoordinator()

        let exercise1 = makeExercise(sets: 2)
        let exercise2 = makeExercise(sets: 3)

        coordinator.startTraining(for: exercise1)
        for _ in 0..<2 { coordinator.completeSet() }

        coordinator.startTraining(for: exercise2)

        coordinator.finishExercise(for: exercise1.id)

        #expect(coordinator.activeSessions[exercise1.id] == nil)
        #expect(coordinator.activeSessions[exercise2.id] != nil)
        #expect(coordinator.focusedExerciseId == exercise2.id)
        #expect(coordinator.lastCompletedExercise?.id == exercise1.id)
    }
}

// MARK: - currentExercise and focus

@Suite("focus management")
@MainActor
struct FocusManagementTests {

    @Test func startTrainingSetsCurrentExerciseAndFocus() {
        let coordinator = makeCoordinator()

        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)

        #expect(coordinator.currentExercise?.id == exercise.id)
        #expect(coordinator.focusedExerciseId == exercise.id)
        #expect(coordinator.isTrainingActive == true)
    }

    @Test func startingSecondExerciseSwitchesFocusButKeepsBoth() {
        let coordinator = makeCoordinator()

        let exercise1 = makeExercise(sets: 2)
        let exercise2 = makeExercise(sets: 3)

        coordinator.startTraining(for: exercise1)
        coordinator.startTraining(for: exercise2)

        #expect(coordinator.focusedExerciseId == exercise2.id)
        #expect(coordinator.currentExercise?.id == exercise2.id)
        #expect(coordinator.activeSessions.count == 2)
        #expect(coordinator.activeSessions[exercise1.id] != nil)
        #expect(coordinator.activeSessions[exercise2.id] != nil)
    }
}

// MARK: - cancelTraining

@Suite("cancelTraining")
@MainActor
struct CancelTrainingTests {

    @Test func resetsCoordinatorState() {
        let coordinator = makeCoordinator()

        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)
        coordinator.cancelTraining()

        #expect(coordinator.currentExercise == nil)
        #expect(coordinator.isTrainingActive == false)
        #expect(coordinator.activeSessions.isEmpty)
    }

    @Test func cancelSpecificExerciseKeepsOthers() {
        let coordinator = makeCoordinator()

        let exercise1 = makeExercise(sets: 2)
        let exercise2 = makeExercise(sets: 3)

        coordinator.startTraining(for: exercise1)
        coordinator.startTraining(for: exercise2)

        coordinator.cancelTraining(for: exercise1.id)

        #expect(coordinator.activeSessions[exercise1.id] == nil)
        #expect(coordinator.activeSessions[exercise2.id] != nil)
        #expect(coordinator.focusedExerciseId == exercise2.id)
    }
}

// MARK: - Multi-session parallel training

@Suite("multi-session parallel training")
@MainActor
struct MultiSessionTests {

    @Test func startingSecondExerciseDoesNotFinishFirst() {
        var updatedExercises: [Exercise] = []

        let coordinator = makeCoordinator(
            onExerciseUpdate: { ex, _ in updatedExercises.append(ex) }
        )

        let exercise1 = makeExercise(sets: 2)
        coordinator.startTraining(for: exercise1)
        coordinator.completeSet()

        let exercise2 = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise2)

        #expect(updatedExercises.isEmpty)
        #expect(coordinator.activeSessions.count == 2)
        #expect(coordinator.hasActiveSessions == true)
    }

    @Test func resumingSameExerciseDoesNotCreateNewSession() {
        let coordinator = makeCoordinator()

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)
        let vm = coordinator.activeSetViewModel
        coordinator.completeSet()

        let progressCount = vm.setProgress.count

        coordinator.startTraining(for: exercise)

        #expect(coordinator.activeSessions.count == 1)
        #expect(coordinator.activeSetViewModel === vm)
        #expect(coordinator.activeSetViewModel.setProgress.count == progressCount)
    }

    @Test func eachExerciseGetsOwnViewModel() {
        let coordinator = makeCoordinator()

        let exercise1 = makeExercise(sets: 2)
        let exercise2 = makeExercise(sets: 4)

        coordinator.startTraining(for: exercise1)
        let vm1 = coordinator.activeSetViewModel
        #expect(vm1.setProgress.count == 2)

        coordinator.startTraining(for: exercise2)
        let vm2 = coordinator.activeSetViewModel
        #expect(vm2.setProgress.count == 4)

        #expect(vm1 !== vm2)
        #expect(vm1.setProgress.count == 2)
    }

    @Test func focusSwitchesActiveSetViewModel() {
        let coordinator = makeCoordinator()

        let exercise1 = makeExercise(sets: 2)
        let exercise2 = makeExercise(sets: 4)

        coordinator.startTraining(for: exercise1)
        let vm1 = coordinator.activeSetViewModel

        coordinator.startTraining(for: exercise2)
        let vm2 = coordinator.activeSetViewModel

        coordinator.focusedExerciseId = exercise1.id
        #expect(coordinator.activeSetViewModel === vm1)

        coordinator.focusedExerciseId = exercise2.id
        #expect(coordinator.activeSetViewModel === vm2)
    }

    @Test func isExerciseInProgressReturnsCorrectState() {
        let coordinator = makeCoordinator()

        let exercise1 = makeExercise(sets: 2)
        let exercise2 = makeExercise(sets: 3)

        coordinator.startTraining(for: exercise1)

        #expect(coordinator.isExerciseInProgress(exercise1.id) == true)
        #expect(coordinator.isExerciseInProgress(exercise2.id) == false)

        coordinator.startTraining(for: exercise2)

        #expect(coordinator.isExerciseInProgress(exercise1.id) == true)
        #expect(coordinator.isExerciseInProgress(exercise2.id) == true)

        coordinator.cancelTraining(for: exercise1.id)

        #expect(coordinator.isExerciseInProgress(exercise1.id) == false)
        #expect(coordinator.isExerciseInProgress(exercise2.id) == true)
    }

    @Test func finishingAllSessionsClearsState() {
        let coordinator = makeCoordinator()

        let exercise1 = makeExercise(sets: 1)
        let exercise2 = makeExercise(sets: 1)

        coordinator.startTraining(for: exercise1)
        coordinator.completeSet()
        coordinator.startTraining(for: exercise2)
        coordinator.completeSet()

        coordinator.finishExercise(for: exercise1.id)
        coordinator.finishExercise(for: exercise2.id)

        #expect(coordinator.activeSessions.isEmpty)
        #expect(coordinator.hasActiveSessions == false)
    }
}

// MARK: - handleQuickDone

@Suite("handleQuickDone")
@MainActor
struct HandleQuickDoneTests {

    @Test func setsAllSetsCompletedAndLastSetCompleted() {
        let coordinator = makeCoordinator()

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)
        coordinator.handleQuickDone()

        let vm = coordinator.activeSetViewModel
        #expect(vm.isLastSetCompleted == true)
        #expect(vm.setProgress.count == 3)
        #expect(vm.setProgress.allSatisfy { $0.status == .completedDone })
    }

    @Test func setsTrainingActiveAfterQuickDone() {
        let coordinator = makeCoordinator()

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)
        coordinator.handleQuickDone()

        #expect(coordinator.isTrainingActive == true)
    }

    @Test func bottomBarShowsFinishAfterQuickDone() {
        let coordinator = makeCoordinator()

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)
        coordinator.handleQuickDone()

        let barVM = coordinator.createBottomActionBarViewModel(
            exercises: [exercise],
            hasActiveExercise: true
        )

        #expect(barVM.showFinishButton == true)
        #expect(barVM.showSetControls == false)
    }
}
