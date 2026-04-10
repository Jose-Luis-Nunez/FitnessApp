import Foundation
import FitnessCore

public struct BottomActionBarViewModel {
    public let isSetInProgress: Bool
    public let currentSet: Int
    public let currentExercise: Exercise?
    public let hasActiveExercise: Bool
    public let exercises: [Exercise]
    public let isLastSetCompleted: Bool
    public let quickDoneModeActive: Bool
    public let quickDoneAllCompleted: Bool
    public let didEditCompleteSet: Bool
    public let didJustEditSet: Bool

    public let showResetAllExercisesButton: Bool

    public init(
        isSetInProgress: Bool,
        currentSet: Int,
        currentExercise: Exercise?,
        hasActiveExercise: Bool,
        exercises: [Exercise],
        isLastSetCompleted: Bool,
        quickDoneModeActive: Bool,
        quickDoneAllCompleted: Bool,
        didEditCompleteSet: Bool,
        didJustEditSet: Bool,
        showResetAllExercisesButton: Bool
    ) {
        self.isSetInProgress = isSetInProgress
        self.currentSet = currentSet
        self.currentExercise = currentExercise
        self.hasActiveExercise = hasActiveExercise
        self.exercises = exercises
        self.isLastSetCompleted = isLastSetCompleted
        self.quickDoneModeActive = quickDoneModeActive
        self.quickDoneAllCompleted = quickDoneAllCompleted
        self.didEditCompleteSet = didEditCompleteSet
        self.didJustEditSet = didJustEditSet
        self.showResetAllExercisesButton = showResetAllExercisesButton
    }

    public var shouldShow: Bool {
        let hasActiveTraining = isSetInProgress || currentExercise != nil
        let hasTrainingActivity = showStartButton || showSetControls || showFinishButton || showQuickDoneBeendenButton || showQuickDoneDoneButton

        return hasActiveTraining && hasTrainingActivity
    }

    public var showStartButton: Bool {
        hasActiveExercise && !isSetInProgress && !isLastSetCompleted && (currentExercise != nil ? currentSet < (currentExercise?.sets ?? 0) : true)
    }

    public var showSetControls: Bool {
        isSetInProgress && hasActiveExercise && !isLastSetCompleted && !quickDoneModeActive
    }

    public var showQuickDoneBeendenButton: Bool {
        quickDoneModeActive && currentExercise != nil && quickDoneAllCompleted
    }

    public var showQuickDoneDoneButton: Bool {
        quickDoneModeActive && currentExercise != nil && !quickDoneAllCompleted
    }

    public var showCategoryResetButton: Bool {
        exercises.allSatisfy { $0.isCompleted } && !isSetInProgress && !exercises.isEmpty
    }

    public var showFinishButton: Bool {
        (isLastSetCompleted || didEditCompleteSet) && currentExercise != nil
    }

    public var showAddExerciseButton: Bool {
        let isStartSetState = showStartButton && (currentSet != 0 || didJustEditSet)
        return !isSetInProgress && !isStartSetState
    }

    public var startButtonTitle: String {
        if currentSet == 0 && !didJustEditSet {
            return "Start Training"
        } else {
            return "Start set \(currentSet + 1)"
        }
    }
}
