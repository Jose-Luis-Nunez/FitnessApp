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
        didJustEditSet: Bool
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
    }

    public var shouldShow: Bool {
        let hasActiveTraining = isSetInProgress || currentExercise != nil
        let hasTrainingActivity = showStartButton || showSetControls || showFinishButton

        return hasActiveTraining && hasTrainingActivity
    }

    public var showStartButton: Bool {
        hasActiveExercise && !isSetInProgress && !isLastSetCompleted && (currentExercise != nil ? currentSet < (currentExercise?.sets ?? 0) : true)
    }

    public var showSetControls: Bool {
        isSetInProgress && hasActiveExercise && !isLastSetCompleted && !quickDoneModeActive
    }

    public var showFinishButton: Bool {
        (isLastSetCompleted || didEditCompleteSet) && currentExercise != nil
    }

    /// The feedback icon-card is rendered whenever the "Finish" button is
    /// visible — i.e. right at the end of an exercise. Uses the same slot
    /// (right of the main capsule) that hosts the quick-done icon-card at
    /// set 0. (Property name retains the historical `Beenden` spelling; the
    /// user-facing label was localised to "Finish".)
    public var showFeedbackButton: Bool {
        showFinishButton
    }

    public var startButtonTitle: String {
        if currentSet == 0 && !didJustEditSet {
            return "Start Training"
        } else {
            return "Start set \(currentSet + 1)"
        }
    }
}
