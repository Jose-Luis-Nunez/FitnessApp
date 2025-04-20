import Foundation

struct BottomActionBarViewModel {
    let isSetInProgress: Bool
    let currentSet: Int
    let currentExercise: Exercise?
    let hasActiveExercise: Bool
    let exercises: [Exercise]
    
    var shouldShow: Bool {
        showSetControls || showStartButton || showResetProgress
    }

    var showResetProgress: Bool {
        !hasActiveExercise && !isSetInProgress && !exercises.isEmpty
    }

    var showSetControls: Bool {
        hasActiveExercise && isSetInProgress
    }

    var showStartButton: Bool {
        hasActiveExercise && !isSetInProgress
    }

    var startTitle: String {
        currentSet == 0 ? "Start Sets" : "Set \(currentSet + 1) Start"
    }
}
