import Foundation

struct BottomActionBarViewModel {
    let isSetInProgress: Bool
    let currentSet: Int
    let currentExercise: Exercise?
    let hasActiveExercise: Bool
    let exercises: [Exercise]
    let isLastSetCompleted: Bool
    
    var shouldShow: Bool {
        showStartButton || showSetControls || showResetProgress || showFinishButton
    }

    var showStartButton: Bool {
        hasActiveExercise && !isSetInProgress && !isLastSetCompleted
    }

    var showSetControls: Bool {
        isSetInProgress && hasActiveExercise && !isLastSetCompleted
    }

    var showResetProgress: Bool {
        !hasActiveExercise && !isSetInProgress && !exercises.isEmpty
    }

    var showFinishButton: Bool {
        isLastSetCompleted && currentExercise != nil
    }

    var startButtonTitle: String {
        if currentSet == 0 {
            return "Start Training"
        } else {
            return "Start set \(currentSet + 1)"
        }
    }
}
