import Foundation
import Mockable

@Mockable
@MainActor
public protocol ExerciseStoring {
    func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise]
    /// Returns all persisted exercise counts grouped by workout id in one
    /// storage read. Overview screens use this instead of issuing one query
    /// per category and workout during SwiftUI rendering. This is a best-effort
    /// overview read: implementations log fetch failures and return an empty map.
    func exerciseCountsByWorkout() -> [UUID: Int]
    func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup)
    /// Targeted, non-destructive update of a single existing exercise (matched by
    /// `id`). Mutates the stored row in place — unlike `saveForWorkout`, which
    /// does a full delete+reinsert. In-place mutation keeps the row identity
    /// stable so a SwiftData `@Query` updates smoothly instead of leaving a
    /// deleted object lingering as a phantom card.
    func updateExercise(_ exercise: Exercise)
}
