import Testing
import Foundation
import FitnessCore
import FitnessTestSupport
@testable import FitnessTraining

@Suite("BottomActionBarViewModel")
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
        didJustEditSet: Bool = false,
        showResetAllExercisesButton: Bool = false
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
            didJustEditSet: didJustEditSet,
            showResetAllExercisesButton: showResetAllExercisesButton
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

    @Test func feedbackButtonVisibleWhenQuickDoneBeendenIsVisible() {
        let exercise = makeExercise(sets: 3)
        let vm = makeViewModel(
            currentExercise: exercise,
            quickDoneModeActive: true,
            quickDoneAllCompleted: true
        )
        #expect(vm.showQuickDoneBeendenButton == true)
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
}
