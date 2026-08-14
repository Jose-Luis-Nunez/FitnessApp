import Testing
import Foundation
import FitnessCore
import FitnessTestSupport
@testable import FitnessTraining

@Suite("BottomActionBarViewModel", .tags(.fast))
@MainActor
struct BottomActionBarViewModelTests {

    private func makeViewModel(
        isSetInProgress: Bool = false,
        currentSet: Int = 0,
        currentExercise: Exercise? = nil,
        hasActiveExercise: Bool = true,
        isLastSetCompleted: Bool = false,
        didEditCompleteSet: Bool = false,
        didJustEditSet: Bool = false
    ) -> BottomActionBarViewModel {
        BottomActionBarViewModel(
            isSetInProgress: isSetInProgress,
            currentSet: currentSet,
            currentExercise: currentExercise,
            hasActiveExercise: hasActiveExercise,
            isLastSetCompleted: isLastSetCompleted,
            didEditCompleteSet: didEditCompleteSet,
            didJustEditSet: didJustEditSet
        )
    }

    @Test func feedbackButtonVisibilityTracksFinishVisibility() {
        let exercise = makeExercise(sets: 3)
        let cases = [
            makeViewModel(),
            makeViewModel(currentExercise: exercise, isLastSetCompleted: true),
            makeViewModel(isSetInProgress: true, currentSet: 1, currentExercise: exercise),
            makeViewModel(currentSet: 0, currentExercise: exercise),
            makeViewModel(currentExercise: exercise, didEditCompleteSet: true),
        ]

        for viewModel in cases {
            #expect(viewModel.showFeedbackButton == viewModel.showFinishButton)
        }
    }

    // MARK: - QuickDone → BottomActionBar integration

    @Test func afterQuickDoneFinishButtonVisibleAndControlsHidden() {
        let exercise = makeExercise(sets: 3)
        let vm = makeViewModel(
            isSetInProgress: false,
            currentSet: 0,
            currentExercise: exercise,
            isLastSetCompleted: true
        )

        #expect(vm.showFinishButton == true, "Finish must be visible after QuickDone")
        #expect(vm.showSetControls == false, "Set controls must be hidden — all sets done")
        #expect(vm.showStartButton == false, "Start must be hidden — all sets done")
        #expect(vm.shouldShow == true, "Bar must remain visible for the Finish button")
    }

}
