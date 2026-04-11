import Foundation
import FitnessCore

@MainActor
public struct ResetExerciseUseCase {

    nonisolated public init() {}

    /// Stops the timer, triggers the exercise reset callback, and clears progress.
    /// - Returns: `true` if the reset was performed, `false` if no valid exercise/category was found.
    @discardableResult
    public func execute(
        activeSetViewModel: ActiveSetViewModel,
        findCategory: (Exercise) -> MuscleCategoryGroup?,
        onExerciseReset: (Exercise, MuscleCategoryGroup) -> Void
    ) -> Bool {
        activeSetViewModel.stopTimer()

        guard let exercise = activeSetViewModel.currentExercise,
              let category = findCategory(exercise) else { return false }

        onExerciseReset(exercise, category)
        activeSetViewModel.resetProgress()

        return true
    }
}
