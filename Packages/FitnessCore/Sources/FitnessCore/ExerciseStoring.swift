import Foundation

@MainActor
public protocol ExerciseStoring {
    func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise]
    func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup)
}
