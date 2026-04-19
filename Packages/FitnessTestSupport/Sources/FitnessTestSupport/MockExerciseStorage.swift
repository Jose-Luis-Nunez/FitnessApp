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
}
