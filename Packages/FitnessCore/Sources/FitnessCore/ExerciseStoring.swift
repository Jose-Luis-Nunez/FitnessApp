import Foundation

@MainActor
public protocol ExerciseStoring {
    /// Monotonically increasing counter; increments on every write.
    /// Observers re-fetch exercises when this changes.
    var changeVersion: Int { get }

    func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise]
    func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup)
}
