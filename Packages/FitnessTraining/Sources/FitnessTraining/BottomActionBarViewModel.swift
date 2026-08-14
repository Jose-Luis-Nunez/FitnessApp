import Foundation
import FitnessCore

public enum TrainingStartLabel: Equatable, Sendable {
    case training
    case left(Int)
    case right(Int)
    case set(Int)
}

public struct BottomActionBarViewModel {
    public let isSetInProgress: Bool
    public let currentSet: Int
    public let currentExercise: Exercise?
    public let hasActiveExercise: Bool
    public let isLastSetCompleted: Bool
    public let didEditCompleteSet: Bool
    public let didJustEditSet: Bool

    public init(
        isSetInProgress: Bool,
        currentSet: Int,
        currentExercise: Exercise?,
        hasActiveExercise: Bool,
        isLastSetCompleted: Bool,
        didEditCompleteSet: Bool,
        didJustEditSet: Bool
    ) {
        self.isSetInProgress = isSetInProgress
        self.currentSet = currentSet
        self.currentExercise = currentExercise
        self.hasActiveExercise = hasActiveExercise
        self.isLastSetCompleted = isLastSetCompleted
        self.didEditCompleteSet = didEditCompleteSet
        self.didJustEditSet = didJustEditSet
    }

    public var shouldShow: Bool {
        let hasActiveTraining = isSetInProgress || currentExercise != nil
        let hasTrainingActivity = showStartButton || showSetControls || showFinishButton

        return hasActiveTraining && hasTrainingActivity
    }

    public var showStartButton: Bool {
        hasActiveExercise && !isSetInProgress && !isLastSetCompleted &&
            (currentExercise != nil ? currentSet < (currentExercise?.trainingSteps.count ?? 0) : true)
    }

    public var showSetControls: Bool {
        isSetInProgress && hasActiveExercise && !isLastSetCompleted
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

    public var startButtonLabel: TrainingStartLabel {
        if currentSet == 0 && !didJustEditSet {
            return .training
        } else {
            guard let exercise = currentExercise,
                  currentSet < exercise.trainingSteps.count else {
                return .training
            }
            let step = exercise.trainingSteps[currentSet]
            let setNumber = step.logicalSetIndex + 1
            switch step.side {
            case .left:
                return .left(setNumber)
            case .right:
                return .right(setNumber)
            case nil:
                return .set(setNumber)
            }
        }
    }
}
