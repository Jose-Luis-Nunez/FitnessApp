import Foundation
/// Persists the observed and learned workout-wide exercise order used by the
/// flattened exercise list. A cycle starts after the previous global reset and
/// ends at the next global "Reset All".
@MainActor
public protocol WorkoutExerciseOrderStoring: AnyObject {
    /// Records the first genuine training start for an exercise in the current
    /// cycle. Implementations must ignore duplicate starts in the same cycle.
    func recordStart(workoutId: UUID, exerciseId: UUID)

    /// Finalizes the current cycle, advances the consecutive-candidate learning
    /// state, and clears the pending starts.
    func finalizeCycle(workoutId: UUID)
}
