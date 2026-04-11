import Foundation
import FitnessCore

public enum StartTrainingResult {
    /// Resumed an existing session for the same exercise.
    case resumed
    /// Started a fresh session (no prior data).
    case started
    /// Auto-finished the previous exercise before starting the new one.
    /// The associated value is the previous exercise if it was marked completed.
    case switchedFrom(previousCompleted: Exercise?)
}

@MainActor
public struct StartTrainingUseCase {

    nonisolated public init() {}

    public func execute(
        exercise: Exercise,
        category: MuscleCategoryGroup,
        activeSetViewModel: ActiveSetViewModel,
        finishPreviousTraining: (() -> Exercise?)?
    ) -> StartTrainingResult {
        let isSameExercise = activeSetViewModel.currentExercise?.id == exercise.id
        let hasTrainingData = activeSetViewModel.isSetInProgress ||
            activeSetViewModel.isLastSetCompleted ||
            !activeSetViewModel.setProgress.isEmpty
        let hasExistingSession = isSameExercise && hasTrainingData

        if hasExistingSession {
            return .resumed
        }

        let hasDifferentActiveExercise = activeSetViewModel.currentExercise != nil
            && !isSameExercise

        if hasDifferentActiveExercise {
            let previousCompleted = finishPreviousTraining?()
            activeSetViewModel.startSet(for: exercise, category: category)
            return .switchedFrom(previousCompleted: previousCompleted)
        }

        activeSetViewModel.startSet(for: exercise, category: category)
        return .started
    }
}
