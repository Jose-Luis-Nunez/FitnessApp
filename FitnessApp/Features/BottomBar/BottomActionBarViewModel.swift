import Foundation

struct BottomActionBarViewModel {
    let isSetInProgress: Bool
    let currentSet: Int
    let currentExercise: Exercise?
    let hasActiveExercise: Bool
    let exercises: [Exercise]
    let isLastSetCompleted: Bool
    let quickDoneModeActive: Bool
    let quickDoneAllCompleted: Bool
    let didEditCompleteSet: Bool
    let didJustEditSet: Bool

    let showResetAllExercisesButton: Bool

    var shouldShow: Bool {
        showStartButton || showSetControls || showResetProgress || showFinishButton || showQuickDoneBeendenButton || showQuickDoneDoneButton || showAddExerciseButton || showResetAllExercisesButton
    }

    var showStartButton: Bool {
        hasActiveExercise && !isSetInProgress && !isLastSetCompleted && (currentExercise != nil ? currentSet < (currentExercise?.sets ?? 0) : true)
    }

    var showSetControls: Bool {
        isSetInProgress && hasActiveExercise && !isLastSetCompleted && !quickDoneModeActive
    }

    var showQuickDoneBeendenButton: Bool {
        quickDoneModeActive && currentExercise != nil && quickDoneAllCompleted
    }

    var showQuickDoneDoneButton: Bool {
        quickDoneModeActive && currentExercise != nil && !quickDoneAllCompleted
    }

    var showResetProgress: Bool {
        exercises.allSatisfy { $0.isCompleted } && !isSetInProgress && !exercises.isEmpty
    }

    var showFinishButton: Bool {
        (isLastSetCompleted || didEditCompleteSet) && currentExercise != nil
    }

    var showAddExerciseButton: Bool {
        !isSetInProgress
    }

    var startButtonTitle: String {
        if currentSet == 0 && !didJustEditSet {
            return "Start Training"
        } else {
            return "Start set \(currentSet + 1)"
        }
    }
}
