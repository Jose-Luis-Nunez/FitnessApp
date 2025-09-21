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
        // Nur anzeigen wenn wirklich ein Training läuft (Set in Progress oder aktuelle Exercise)
        let hasActiveTraining = isSetInProgress || currentExercise != nil
        let hasTrainingActivity = showStartButton || showSetControls || showFinishButton || showQuickDoneBeendenButton || showQuickDoneDoneButton
        
        return hasActiveTraining && hasTrainingActivity
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

    var showCategoryResetButton: Bool {
        exercises.allSatisfy { $0.isCompleted } && !isSetInProgress && !exercises.isEmpty
    }

    var showFinishButton: Bool {
        (isLastSetCompleted || didEditCompleteSet) && currentExercise != nil
    }

    var showAddExerciseButton: Bool {
        // Hide "Add Exercise" when we are in the state that shows "Start set X"
        // i.e., when a start button is visible and it's not the initial "Start Training" state
        let isStartSetState = showStartButton && (currentSet != 0 || didJustEditSet)
        return !isSetInProgress && !isStartSetState
    }

    var startButtonTitle: String {
        if currentSet == 0 && !didJustEditSet {
            return "Start Training"
        } else {
            return "Start set \(currentSet + 1)"
        }
    }
}
