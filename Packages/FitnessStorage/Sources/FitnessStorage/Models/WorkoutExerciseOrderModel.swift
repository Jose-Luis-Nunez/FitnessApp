import Foundation
import SwiftData

/// Workout-local learning state for the flattened exercise list.
///
/// Kept separate from `ExerciseModel.sortOrder`: that field describes manual
/// placement within one muscle category, while this model stores one order
/// across every category in a workout.
@_spi(PersistenceUI)
@Model
public final class WorkoutExerciseOrderModel {
    @_spi(PersistenceUI) @Attribute(.unique) public var workoutId: UUID
    @_spi(PersistenceUI) public var pendingExerciseIds: [UUID]
    @_spi(PersistenceUI) public var candidateExerciseIds: [UUID]
    @_spi(PersistenceUI) public var candidateRepeatCount: Int
    @_spi(PersistenceUI) public var learnedExerciseIds: [UUID]

    @_spi(PersistenceUI) public init(
        workoutId: UUID,
        pendingExerciseIds: [UUID] = [],
        candidateExerciseIds: [UUID] = [],
        candidateRepeatCount: Int = 0,
        learnedExerciseIds: [UUID] = []
    ) {
        self.workoutId = workoutId
        self.pendingExerciseIds = pendingExerciseIds
        self.candidateExerciseIds = candidateExerciseIds
        self.candidateRepeatCount = candidateRepeatCount
        self.learnedExerciseIds = learnedExerciseIds
    }
}
