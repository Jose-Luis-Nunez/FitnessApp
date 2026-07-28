import FitnessCore

/// Calculates the next idle-card values after a successfully completed exercise.
///
/// A weight increase is earned only when every recorded set is complete, uses
/// a higher weight, and reaches the fixed twelve-repetition threshold. The
/// lowest recorded weight becomes the next idle-card value, ensuring it was
/// achieved across the entire session.
/// The exercise's configured number of sets is never changed.
public struct ExerciseWeightProgressionUseCase {
    private static let requiredReps = 12

    nonisolated public init() {}

    /// Returns the progressed exercise, or the original exercise when the
    /// session does not satisfy the weight-progression rule.
    public func execute(exercise: Exercise, setProgress: [SetProgress]) -> Exercise {
        guard exercise.hasWeight,
              setProgress.count >= exercise.sets,
              setProgress.allSatisfy(isCompleted),
              setProgress.allSatisfy({ $0.currentReps >= Self.requiredReps }),
              let trainedWeight = setProgress.map(\.weight).min(),
              trainedWeight > exercise.weight else {
            return exercise
        }

        var progressedExercise = exercise
        progressedExercise.weight = trainedWeight
        progressedExercise.reps = Self.requiredReps
        return progressedExercise
    }

    private func isCompleted(_ progress: SetProgress) -> Bool {
        switch progress.status {
        case .completedDone, .completedLess, .completedMore:
            true
        case .notStarted, .inProgress:
            false
        }
    }
}
