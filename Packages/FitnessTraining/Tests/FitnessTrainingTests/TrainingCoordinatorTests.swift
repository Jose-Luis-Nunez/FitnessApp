import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessAnalytics
import FitnessStorage
import FitnessTestSupport

// MARK: - Helpers

@MainActor
private func makeCoordinator(
    onExerciseUpdate: @escaping (Exercise, MuscleCategoryGroup) -> Void = { _, _ in },
    onExerciseReset: @escaping (Exercise, MuscleCategoryGroup) -> Void = { _, _ in }
) -> TrainingCoordinator {
    TrainingCoordinator(
        findCategory: { _ in .arms },
        onExerciseUpdate: onExerciseUpdate,
        onExerciseReset: onExerciseReset,
        analyticsViewModel: AnalyticsViewModel(storageService: StubAnalyticsStorage())
    )
}

// MARK: - finishExercise

@Suite("finishExercise", .tags(.fast))
@MainActor
struct FinishExerciseTests {

    @Test func setsCurrentExerciseToNilAndIsTrainingActiveToFalse() throws {
        let coordinator = makeCoordinator()

        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)
        let currentBefore = try #require(coordinator.currentExercise)
        #expect(currentBefore.id == exercise.id)
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

    @Test func persistsEarnedWeightProgressionWhenFinishingExercise() {
        let exercise = makeExercise(weight: 20, reps: 10, sets: 3)
        let exerciseManagement = MockExerciseManagement()
        exerciseManagement.exercisesByCategory[.arms] = [exercise]
        let cache = TrainingCoordinatorCache(exerciseManagement: exerciseManagement)
        let coordinator = cache.coordinator(for: .arms)
        coordinator.startTraining(for: exercise)

        let vm = coordinator.activeSetViewModel
        vm.updateCurrentReps(12, 21)
        vm.startNextSet()
        vm.updateCurrentReps(15, 21)
        vm.startNextSet()
        vm.updateCurrentReps(12, 21)

        coordinator.finishExercise()

        let persistedExercise = exerciseManagement.getExercises(for: .arms).first
        #expect(persistedExercise?.weight == 21)
        #expect(persistedExercise?.reps == 12)
        #expect(persistedExercise?.sets == 3)
        #expect(persistedExercise?.isCompleted == true)
        #expect(coordinator.lastCompletedExercise?.weight == 21)
    }

    @Test func setsLastCompletedExerciseWhenAllSetsFinished() throws {
        let coordinator = makeCoordinator()

        let exercise = makeExercise(sets: 2)
        coordinator.startTraining(for: exercise)

        for _ in 0..<2 { coordinator.completeSet() }
        coordinator.finishExercise()

        let completed = try #require(coordinator.lastCompletedExercise)
        #expect(completed.id == exercise.id)
        #expect(completed.isCompleted == true)
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

@Suite("focus management", .tags(.fast))
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

@Suite("cancelTraining", .tags(.fast))
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

@Suite("multi-session parallel training", .tags(.fast))
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

@Suite("handleQuickDone", .tags(.fast))
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

// MARK: - editLess / editMore

@Suite("editLess and editMore", .tags(.fast))
@MainActor
struct EditLessMoreTests {

    @Test func editLessSetsEditingModeToLess() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)

        coordinator.editLess()

        let vm = coordinator.activeSetViewModel
        #expect(vm.isEditing == true)
        #expect(vm.editMode == .less)
        #expect(vm.pendingEditIndex == 0)
    }

    @Test func editMoreSetsEditingModeToMore() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)

        coordinator.editMore()

        let vm = coordinator.activeSetViewModel
        #expect(vm.isEditing == true)
        #expect(vm.editMode == .more)
        #expect(vm.pendingEditIndex == 0)
    }

    @Test func editLessDoesNothingWithoutActiveSets() {
        let coordinator = makeCoordinator()

        coordinator.editLess()

        let vm = coordinator.activeSetViewModel
        #expect(vm.isEditing == false)
    }

    @Test func editMoreDoesNothingWithoutActiveSets() {
        let coordinator = makeCoordinator()

        coordinator.editMore()

        let vm = coordinator.activeSetViewModel
        #expect(vm.isEditing == false)
    }

    @Test func editLessStopsTimer() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)

        let vm = coordinator.activeSetViewModel
        #expect(vm.isSetInProgress == true)

        coordinator.editLess()

        #expect(vm.isEditing == true)
    }

    @Test func editLessEditsCorrectSetAfterCompletion() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)

        coordinator.completeSet()
        coordinator.activeSetViewModel.startNextSet()

        coordinator.editLess()

        let vm = coordinator.activeSetViewModel
        #expect(vm.pendingEditIndex == 1)
        #expect(vm.editMode == .less)
    }
}

// MARK: - updateActiveSeat

@Suite("updateActiveSeat", .tags(.fast))
@MainActor
struct UpdateActiveSeatTests {

    @Test func updatesInFlightSnapshot() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise(sets: 2, seatSetting: "3")
        coordinator.startTraining(for: exercise)

        coordinator.updateActiveSeat("5 / 2")

        #expect(coordinator.activeSetViewModel.currentExercise?.seatSetting == "5 / 2")
    }

    /// The seat must persist through the single exercise-write path
    /// (`onExerciseUpdate` → storage), NOT a direct main-context `@Model` write —
    /// otherwise it conflicts with the storage service's delete+reinsert and
    /// leaves phantom cards in the category `@Query`.
    @Test func persistsViaOnExerciseUpdate() {
        var received: Exercise?
        let coordinator = makeCoordinator(
            onExerciseUpdate: { ex, _ in received = ex }
        )
        let exercise = makeExercise(sets: 2, seatSetting: "3")
        coordinator.startTraining(for: exercise)

        coordinator.updateActiveSeat("5 / 2")

        #expect(received?.id == exercise.id)
        #expect(received?.seatSetting == "5 / 2")
    }

    @Test func nilClearsSeat() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise(sets: 2, seatSetting: "3")
        coordinator.startTraining(for: exercise)

        coordinator.updateActiveSeat(nil)

        #expect(coordinator.activeSetViewModel.currentExercise?.seatSetting == nil)
    }

    /// Regression for the mid-session seat edit being reverted on finish:
    /// `finishExercise` re-persists the in-flight snapshot via `onExerciseUpdate`,
    /// so the seat edited during the session must survive to that callback.
    @Test func editedSeatSurvivesFinish() {
        var receivedExercise: Exercise?
        let coordinator = makeCoordinator(
            onExerciseUpdate: { ex, _ in receivedExercise = ex }
        )
        let exercise = makeExercise(sets: 1, seatSetting: "3")
        coordinator.startTraining(for: exercise)

        coordinator.updateActiveSeat("9")
        coordinator.completeSet()
        coordinator.finishExercise()

        #expect(receivedExercise?.seatSetting == "9")
        #expect(receivedExercise?.isCompleted == true)
    }

    @Test func doesNothingWithoutActiveSession() {
        let coordinator = makeCoordinator()

        coordinator.updateActiveSeat("5")

        #expect(coordinator.activeSetViewModel.currentExercise == nil)
    }
}

// MARK: - setCurrentExercise

@Suite("setCurrentExercise", .tags(.fast))
@MainActor
struct SetCurrentExerciseTests {

    @Test func setsExerciseAndCreateSession() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise()

        coordinator.setCurrentExercise(exercise)

        #expect(coordinator.focusedExerciseId == exercise.id)
        #expect(coordinator.activeSessions[exercise.id] != nil)
        #expect(coordinator.activeSetViewModel.currentExercise?.id == exercise.id)
    }

    @Test func settingNilClearsFocus() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise()

        coordinator.setCurrentExercise(exercise)
        coordinator.setCurrentExercise(nil)

        #expect(coordinator.focusedExerciseId == nil)
    }

    @Test func doesNotReplaceExistingSession() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise()

        coordinator.startTraining(for: exercise)
        let originalVM = coordinator.activeSessions[exercise.id]

        coordinator.setCurrentExercise(exercise)

        #expect(coordinator.activeSessions[exercise.id] === originalVM)
    }

    @Test func switchesFocusBetweenExercises() {
        let coordinator = makeCoordinator()
        let exercise1 = makeExercise(sets: 2)
        let exercise2 = makeExercise(sets: 3)

        coordinator.setCurrentExercise(exercise1)
        coordinator.setCurrentExercise(exercise2)

        #expect(coordinator.focusedExerciseId == exercise2.id)
        #expect(coordinator.activeSessions.count == 2)
    }
}

// MARK: - createTrainingCallbacks

@Suite("createTrainingCallbacks", .tags(.fast))
@MainActor
struct CreateTrainingCallbacksTests {

    @Test func onCompleteSetDelegatesToCoordinator() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)

        let callbacks = coordinator.createTrainingCallbacks()
        callbacks.onCompleteSet()

        #expect(coordinator.activeSetViewModel.currentSet == 1)
    }

    @Test func onQuickDoneDelegatesToCoordinator() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)

        let callbacks = coordinator.createTrainingCallbacks()
        callbacks.onQuickDone()

        #expect(coordinator.activeSetViewModel.isLastSetCompleted == true)
        #expect(coordinator.activeSetViewModel.setProgress.allSatisfy { $0.status == .completedDone })
    }

    @Test func onFinishDelegatesToCoordinator() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise(sets: 1)
        coordinator.startTraining(for: exercise)
        coordinator.completeSet()

        let callbacks = coordinator.createTrainingCallbacks()
        callbacks.onFinish()

        #expect(coordinator.currentExercise == nil)
        #expect(coordinator.isTrainingActive == false)
    }

    @Test func onCategoryResetDelegatesToCoordinator() {
        var resetCalled = false

        let coordinator = makeCoordinator(
            onExerciseReset: { _, _ in resetCalled = true }
        )
        let exercise = makeExercise(sets: 2)
        coordinator.startTraining(for: exercise)

        let callbacks = coordinator.createTrainingCallbacks()
        callbacks.onCategoryReset()

        #expect(resetCalled == true)
        #expect(coordinator.activeSessions.isEmpty)
    }

    @Test func onAddExerciseDelegatesToCallback() {
        var addCalled = false
        let coordinator = TrainingCoordinator(
            findCategory: { _ in .arms },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in },
            onAddExercise: { addCalled = true },
            analyticsViewModel: AnalyticsViewModel(storageService: StubAnalyticsStorage())
        )

        let callbacks = coordinator.createTrainingCallbacks()
        callbacks.onAddExercise()

        #expect(addCalled == true)
    }

    @Test func onResetAllExercisesDelegatesToCallback() {
        var resetAllCalled = false
        let coordinator = TrainingCoordinator(
            findCategory: { _ in .arms },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in },
            onResetAllExercises: { resetAllCalled = true },
            analyticsViewModel: AnalyticsViewModel(storageService: StubAnalyticsStorage())
        )

        let callbacks = coordinator.createTrainingCallbacks()
        callbacks.onResetAllExercises()

        #expect(resetAllCalled == true)
    }

    @Test func onEditLessDelegatesToCoordinator() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)

        let callbacks = coordinator.createTrainingCallbacks()
        callbacks.onEditLess()

        #expect(coordinator.activeSetViewModel.isEditing == true)
        #expect(coordinator.activeSetViewModel.editMode == .less)
    }

    @Test func onEditMoreDelegatesToCoordinator() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)

        let callbacks = coordinator.createTrainingCallbacks()
        callbacks.onEditMore()

        #expect(coordinator.activeSetViewModel.isEditing == true)
        #expect(coordinator.activeSetViewModel.editMode == .more)
    }
}

// MARK: - resetExercise

@Suite("resetExercise", .tags(.fast))
@MainActor
struct ResetExerciseCoordinatorTests {

    @Test func removesSessionAndClearsFocus() {
        var resetCalled = false
        let coordinator = makeCoordinator(
            onExerciseReset: { _, _ in resetCalled = true }
        )
        let exercise = makeExercise(sets: 2)
        coordinator.startTraining(for: exercise)

        #expect(coordinator.activeSessions.count == 1)

        coordinator.resetExercise()

        #expect(resetCalled == true)
        #expect(coordinator.activeSessions.isEmpty)
        #expect(coordinator.focusedExerciseId == nil)
    }

    @Test func doesNothingWithoutFocusedExercise() {
        var resetCalled = false
        let coordinator = makeCoordinator(
            onExerciseReset: { _, _ in resetCalled = true }
        )

        coordinator.resetExercise()

        #expect(resetCalled == false)
    }

    @Test func keepsOtherSessionsWhenResetting() {
        let coordinator = makeCoordinator(
            onExerciseReset: { _, _ in }
        )
        let exercise1 = makeExercise(sets: 2)
        let exercise2 = makeExercise(sets: 3)

        coordinator.startTraining(for: exercise1)
        coordinator.startTraining(for: exercise2)

        #expect(coordinator.activeSessions.count == 2)

        coordinator.resetExercise()

        #expect(coordinator.activeSessions.count == 1)
        #expect(coordinator.activeSessions[exercise1.id] != nil)
    }
}

// MARK: - Factory integration (via TrainingCoordinatorCache)

// StubExerciseManagement replaced by MockExerciseManagement from FitnessTestSupport

@Suite("Factory integration", .tags(.fast))
@MainActor
struct FactoryIntegrationTests {

    @Test func coordinatorFromCacheStartsAndFinishesTraining() {
        let mock = MockExerciseManagement()
        let cache = TrainingCoordinatorCache(exerciseManagement: mock)
        let coordinator = cache.coordinator(for: .arms)

        let exercise = makeExercise(sets: 2)
        coordinator.startTraining(for: exercise)

        #expect(coordinator.isTrainingActive == true)
        #expect(coordinator.currentExercise?.id == exercise.id)

        for _ in 0..<2 { coordinator.completeSet() }
        coordinator.finishExercise()

        #expect(coordinator.currentExercise == nil)
        #expect(coordinator.isTrainingActive == false)
        #expect(mock.updatedExercises.count == 1)
        #expect(mock.updatedExercises.first?.isCompleted == true)
    }

    @Test func coordinatorFromCacheResetsExercise() {
        let mock = MockExerciseManagement()
        let cache = TrainingCoordinatorCache(exerciseManagement: mock)
        let coordinator = cache.coordinator(for: .chest)

        let exercise = makeExercise(sets: 3, category: .chest)
        coordinator.startTraining(for: exercise)
        coordinator.resetExercise()

        #expect(coordinator.activeSessions.isEmpty)
        #expect(mock.resetExercises.count == 1)
    }
}

// MARK: - startTraining edge cases

@Suite("startTraining edge cases", .tags(.fast))
@MainActor
struct StartTrainingEdgeCaseTests {

    @Test func findCategoryReturningNilIsNoOp() {
        let coordinator = TrainingCoordinator(
            findCategory: { _ in nil },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in },
            analyticsViewModel: AnalyticsViewModel(storageService: StubAnalyticsStorage())
        )

        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)

        #expect(coordinator.currentExercise == nil)
        #expect(coordinator.isTrainingActive == false)
        #expect(coordinator.activeSessions.isEmpty)
    }
}
