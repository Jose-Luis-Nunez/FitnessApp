import Foundation
import FitnessCore

@MainActor
public final class MockExerciseStorage: ExerciseStoring {
    public var exercisesByCategory: [MuscleCategoryGroup: [Exercise]] = [:]
    public var loadForWorkoutHandler: ((UUID, MuscleCategoryGroup) -> [Exercise])?
    public private(set) var saveForWorkoutCallCount = 0
    public private(set) var updatedExercises: [Exercise] = []
    private var countsByWorkout: [UUID: [MuscleCategoryGroup: Int]] = [:]

    public init() {}

    public func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise] {
        if let loadForWorkoutHandler {
            return loadForWorkoutHandler(workoutId, category)
        }
        return exercisesByCategory[category] ?? []
    }

    public func exerciseCountsByWorkout() -> [UUID: Int] {
        countsByWorkout.mapValues { counts in
            counts.values.reduce(0, +)
        }
    }

    public func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        saveForWorkoutCallCount += 1
        exercisesByCategory[category] = exercises
        countsByWorkout[workoutId, default: [:]][category] = exercises.count
    }

    public func updateExercise(_ exercise: Exercise) {
        updatedExercises.append(exercise)
        for (category, exercises) in exercisesByCategory {
            if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                exercisesByCategory[category]?[index] = exercise
                return
            }
        }
    }
}
