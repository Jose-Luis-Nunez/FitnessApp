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
    
    var shouldShow: Bool {
        showStartButton || showSetControls || showResetProgress || showFinishButton || showAddExerciseButton || showQuickDoneBeendenButton || showQuickDoneDoneButton
    }

    var showStartButton: Bool {
        hasActiveExercise && !isSetInProgress && !isLastSetCompleted
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
        !hasActiveExercise && !isSetInProgress && !exercises.isEmpty
    }

    var showFinishButton: Bool {
        isLastSetCompleted && currentExercise != nil
    }

    var showAddExerciseButton: Bool {
        (exercises.isEmpty || (showStartButton && currentSet == 0) || showResetProgress)
    }

    var startButtonTitle: String {
        if currentSet == 0 {
            return "Start Training"
        } else {
            return "Start set \(currentSet + 1)"
        }
    }
}
