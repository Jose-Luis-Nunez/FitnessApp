import Foundation
import FitnessCore
import FitnessAnalytics

@MainActor
public struct FinishExerciseUseCase {
    private let weightProgressionUseCase = ExerciseWeightProgressionUseCase()

    nonisolated public init() {}

    /// Stops the timer, saves analytics, marks the exercise completed if all sets done,
    /// and resets the active set state.
    /// - Returns: The completed exercise if all sets were finished, otherwise `nil`.
    public func execute(
        activeSetViewModel: ActiveSetViewModel,
        analyticsViewModel: AnalyticsViewModel,
        findCategory: (Exercise) -> MuscleCategoryGroup?,
        onExerciseUpdate: (Exercise, MuscleCategoryGroup) -> Void
    ) -> Exercise? {
        activeSetViewModel.stopTimer()

        guard let exercise = activeSetViewModel.currentExercise,
              let category = findCategory(exercise) else { return nil }

        if !activeSetViewModel.setProgress.isEmpty {
            analyticsViewModel.saveAnalytics(
                exerciseId: exercise.id,
                setProgress: activeSetViewModel.setProgress
            )
        }

        var completedExercise: Exercise?
        if activeSetViewModel.isLastSetCompleted {
            var updated = weightProgressionUseCase.execute(
                exercise: exercise,
                setProgress: activeSetViewModel.setProgress
            )
            updated.isCompleted = true
            onExerciseUpdate(updated, category)
            completedExercise = updated
        }

        activeSetViewModel.finishExercise()

        return completedExercise
    }
}
