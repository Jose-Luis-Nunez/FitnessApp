import Testing
import Foundation
import FitnessCore
import FitnessTestSupport
@testable import FitnessTraining

@Suite("BottomActionBarViewModel")
@MainActor
struct BottomActionBarViewModelTests {

    private func makeViewModel(
        isSetInProgress: Bool = false,
        currentSet: Int = 0,
        currentExercise: Exercise? = nil,
        hasActiveExercise: Bool = true,
        exercises: [Exercise] = [],
        isLastSetCompleted: Bool = false,
        quickDoneModeActive: Bool = false,
        quickDoneAllCompleted: Bool = false,
        didEditCompleteSet: Bool = false,
        didJustEditSet: Bool = false
    ) -> BottomActionBarViewModel {
        BottomActionBarViewModel(
            isSetInProgress: isSetInProgress,
            currentSet: currentSet,
            currentExercise: currentExercise,
            hasActiveExercise: hasActiveExercise,
            exercises: exercises,
            isLastSetCompleted: isLastSetCompleted,
            quickDoneModeActive: quickDoneModeActive,
            quickDoneAllCompleted: quickDoneAllCompleted,
            didEditCompleteSet: didEditCompleteSet,
            didJustEditSet: didJustEditSet
        )
    }

    @Test func feedbackButtonHiddenWhenIdle() {
        let vm = makeViewModel()
        #expect(vm.showFeedbackButton == false)
    }

    @Test func feedbackButtonVisibleWhenFinishIsVisible() {
        let exercise = makeExercise(sets: 3)
        let vm = makeViewModel(
            currentExercise: exercise,
            isLastSetCompleted: true
        )
        #expect(vm.showFinishButton == true)
        #expect(vm.showFeedbackButton == true)
    }

    @Test func feedbackButtonHiddenDuringActiveSet() {
        let exercise = makeExercise(sets: 3)
        let vm = makeViewModel(
            isSetInProgress: true,
            currentSet: 1,
            currentExercise: exercise
        )
        #expect(vm.showFeedbackButton == false)
    }

    @Test func feedbackButtonHiddenAtStartOfExercise() {
        let exercise = makeExercise(sets: 3)
        let vm = makeViewModel(
            currentSet: 0,
            currentExercise: exercise
        )
        #expect(vm.showStartButton == true)
        #expect(vm.showFeedbackButton == false)
    }

    @Test func feedbackButtonVisibleAfterEditCompletingSet() {
        let exercise = makeExercise(sets: 3)
        let vm = makeViewModel(
            currentExercise: exercise,
            didEditCompleteSet: true
        )
        #expect(vm.showFinishButton == true)
        #expect(vm.showFeedbackButton == true)
    }

    // MARK: - QuickDone → BottomActionBar integration

    @Test func afterQuickDoneFinishButtonVisibleAndControlsHidden() {
        let exercise = makeExercise(sets: 3)
        let vm = makeViewModel(
            isSetInProgress: false,
            currentSet: 0,
            currentExercise: exercise,
            isLastSetCompleted: true,
            quickDoneAllCompleted: true
        )

        #expect(vm.showFinishButton == true, "Finish must be visible after QuickDone")
        #expect(vm.showSetControls == false, "Set controls must be hidden — all sets done")
        #expect(vm.showStartButton == false, "Start must be hidden — all sets done")
        #expect(vm.shouldShow == true, "Bar must remain visible for the Finish button")
    }

    @Test func afterCompleteAllQuickDoneFinishButtonVisibleAndControlsHidden() {
        let exercise = makeExercise(sets: 3)
        let vm = makeViewModel(
            isSetInProgress: false,
            currentExercise: exercise,
            isLastSetCompleted: true,
            quickDoneAllCompleted: true,
            didEditCompleteSet: false
        )

        #expect(vm.showFinishButton == true)
        #expect(vm.showSetControls == false)
        #expect(vm.showStartButton == false)
        #expect(vm.shouldShow == true)
    }
}

// MARK: - End-to-End: ActiveSetViewModel → BottomActionBarViewModel

@Suite("QuickDone → BottomActionBar E2E")
@MainActor
struct QuickDoneBottomActionBarE2ETests {

    private func makeActionBar(from vm: ActiveSetViewModel, exercises: [Exercise]) -> BottomActionBarViewModel {
        BottomActionBarViewModel(
            isSetInProgress: vm.isSetInProgress,
            currentSet: vm.currentSet,
            currentExercise: vm.currentExercise,
            hasActiveExercise: vm.currentExercise != nil,
            exercises: exercises,
            isLastSetCompleted: vm.isLastSetCompleted,
            quickDoneModeActive: vm.quickDoneModeActive,
            quickDoneAllCompleted: vm.quickDoneAllCompleted,
            didEditCompleteSet: vm.didEditCompleteSet,
            didJustEditSet: vm.didJustEditSet
        )
    }

    @Test func startQuickDoneShowsFinishButton() {
        let exercise = makeExercise(sets: 3)
        let vm = ActiveSetViewModel()
        vm.startQuickDone(for: exercise, category: .arms)

        let bar = makeActionBar(from: vm, exercises: [exercise])

        #expect(bar.showFinishButton == true, "Finish must be visible after startQuickDone")
        #expect(bar.showSetControls == false, "No set controls — all sets already done")
        #expect(bar.showStartButton == false, "No start — all sets already done")
        #expect(bar.shouldShow == true, "Bar must stay visible so user can finish")
    }

    @Test func completeAllQuickDoneShowsFinishButton() {
        let exercise = makeExercise(sets: 3)
        let vm = ActiveSetViewModel()
        vm.startSet(for: exercise, category: .arms)
        vm.completeAllQuickDone()

        let bar = makeActionBar(from: vm, exercises: [exercise])

        #expect(bar.showFinishButton == true)
        #expect(bar.showSetControls == false)
        #expect(bar.showStartButton == false)
        #expect(bar.shouldShow == true)
    }

    @Test func processQuickDoneCompletingAllShowsFinishButton() {
        let exercise = makeExercise(sets: 2)
        let vm = ActiveSetViewModel()
        vm.startSet(for: exercise, category: .arms)

        vm.completeCurrentSet()
        vm.processQuickDone(at: 1)

        let bar = makeActionBar(from: vm, exercises: [exercise])

        #expect(bar.showFinishButton == true)
        #expect(bar.showSetControls == false)
        #expect(bar.shouldShow == true)
    }
}
