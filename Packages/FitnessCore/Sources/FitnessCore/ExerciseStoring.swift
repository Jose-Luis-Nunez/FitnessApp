import Foundation

public protocol ExerciseStoring {
    func load(for group: MuscleCategoryGroup) -> [Exercise]
    func save(_ exercises: [Exercise], for group: MuscleCategoryGroup)
    func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise]
    func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup)
}
