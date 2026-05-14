import Foundation
import Mockable

@Mockable
@MainActor
public protocol WorkoutStoring: AnyObject {
    var workouts: [Workout] { get set }
    var currentWorkout: Workout? { get set }
    var defaultWorkout: Workout? { get set }

    func createWorkout(name: String, selectedCategories: Set<MuscleCategoryGroup>) -> Workout
    func duplicateWorkout(_ workout: Workout) -> Workout
    /// Persists an imported workout — sourced from a shared JSON envelope —
    /// alongside its exercises and analytics history. Implementations MUST:
    ///
    /// - Resolve name collisions against existing workouts by appending
    ///   " (imported)" / " (imported 2)" / … so the existing workout with
    ///   the same name remains untouched.
    /// - Override `workout.isDefault` to `false` (the flag is per-device).
    /// - Persist exercises bucketed by category via the exercise storage.
    /// - Persist analytics entries bucketed by exerciseId via analytics storage.
    ///
    /// Callers (`ImportWorkoutUseCase`) are responsible for generating fresh
    /// UUIDs for the workout, all exercises, and all analytics entries
    /// **before** calling, plus remapping `AnalyticsEntry.exerciseId` to point
    /// at the new exercise IDs.
    func importWorkout(_ workout: Workout, exercises: [Exercise], analytics: [AnalyticsEntry]) -> Workout
    func deleteWorkout(_ workout: Workout)
    func updateWorkout(_ workout: Workout)
    func setCurrentWorkout(_ workout: Workout)
    func setAsDefaultWorkout(_ workout: Workout)
    func removeAsDefaultWorkout()
    func renameWorkout(_ workout: Workout, newName: String)
}
