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
              hasRequiredExecutionShape(exercise: exercise, setProgress: setProgress),
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

    private func hasRequiredExecutionShape(
        exercise: Exercise,
        setProgress: [SetProgress]
    ) -> Bool {
        guard exercise.executionMode == .bilateral else {
            // Preserve the established standard-exercise behavior: imported
            // or historic sessions may contain additional completed sets.
            return setProgress.count >= exercise.trainingSteps.count
        }

        let expectedSteps = exercise.trainingSteps
        guard setProgress.count == expectedSteps.count else { return false }

        return zip(setProgress, expectedSteps).allSatisfy { progress, step in
            progress.side == step.side
                && progress.logicalSetIndex == step.logicalSetIndex
        }
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
