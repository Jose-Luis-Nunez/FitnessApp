import Foundation
import FitnessCore

@MainActor
public struct CompleteSetUseCase {

    nonisolated public init() {}

    /// Validates and completes the current set, then starts the next set if not the last.
    /// Returns `true` if a set was completed, `false` if the action was invalid.
    @discardableResult
    public func execute(activeSetViewModel: ActiveSetViewModel) -> Bool {
        guard let exercise = activeSetViewModel.currentExercise else { return false }

        let stepCount = exercise.trainingSteps.count
        guard activeSetViewModel.currentSet < stepCount &&
              !activeSetViewModel.isLastSetCompleted else { return false }

        activeSetViewModel.stopTimer()

        let isLastSet = (activeSetViewModel.currentSet + 1) >= stepCount

        activeSetViewModel.completeCurrentSet()

        if !isLastSet {
            activeSetViewModel.startNextSet()
        }

        return true
    }
}
