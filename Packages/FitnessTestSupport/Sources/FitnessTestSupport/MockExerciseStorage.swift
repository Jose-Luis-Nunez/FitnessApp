import Foundation
import FitnessCore

@MainActor
public final class MockExerciseStorage: ExerciseStoring {
    public var exercisesByCategory: [MuscleCategoryGroup: [Exercise]] = [:]

    public init() {}

    public func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise] {
        exercisesByCategory[category] ?? []
    }

    public func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        exercisesByCategory[category] = exercises
    }

    public func updateExercise(_ exercise: Exercise) {
        for (category, exercises) in exercisesByCategory {
            if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                exercisesByCategory[category]?[index] = exercise
                return
            }
        }
    }
}
