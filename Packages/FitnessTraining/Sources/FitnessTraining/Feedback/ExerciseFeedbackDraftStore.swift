import Foundation
import Observation
import FitnessCore

/// Single-slot, in-memory store for the **draft** of a feedback record that the
/// user has begun editing but not yet saved. Drafts live exclusively in
/// memory — they are never written to SwiftData. The store holds at most one
/// draft at a time: the one for the currently active exercise. Switching to
/// another exercise discards the previous draft (silent discard, see
/// `handleActiveExerciseChange(to:)`).
///
/// Why a single slot and not a `[UUID: ExerciseFeedback]` dictionary: the
/// product rule is "draft scope = exercise" — there can never be more than one
/// draft alive at once, because focus on a different exercise immediately
/// invalidates the previous draft. Encoding the invariant in the type prevents
/// callers from accidentally retaining drafts across exercises.
@MainActor
@Observable
public final class ExerciseFeedbackDraftStore {
    public private(set) var current: ExerciseFeedback?

    public init() {}

    /// Returns the currently held draft if (and only if) it belongs to
    /// `exerciseId`. Returns `nil` for any other exercise so callers cannot
    /// accidentally hydrate a sheet with another exercise's data.
    public func draft(for exerciseId: UUID) -> ExerciseFeedback? {
        guard let current, current.exerciseId == exerciseId else { return nil }
        return current
    }

    public func setDraft(_ feedback: ExerciseFeedback) {
        current = feedback
    }

    public func clear() {
        current = nil
    }

    /// Called by `TrainingCoordinator` whenever the focused exercise changes.
    /// If the held draft does not belong to the new active exercise, it is
    /// discarded — this is the "silent discard on exercise switch" behaviour
    /// from the product spec. Passing `nil` (no exercise active) also discards
    /// any held draft.
    public func handleActiveExerciseChange(to newExerciseId: UUID?) {
        guard let current else { return }
        if current.exerciseId != newExerciseId {
            self.current = nil
        }
    }
}
