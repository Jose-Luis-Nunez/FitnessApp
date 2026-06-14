import Foundation
import Mockable

@Mockable
@MainActor
public protocol ExerciseStoring {
    func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise]
    func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup)
    /// Targeted, non-destructive update of a single existing exercise (matched by
    /// `id`). Mutates the stored row in place — unlike `saveForWorkout`, which
    /// does a full delete+reinsert. In-place mutation keeps the row identity
    /// stable so a SwiftData `@Query` updates smoothly instead of leaving a
    /// deleted object lingering as a phantom card.
    func updateExercise(_ exercise: Exercise)
}
