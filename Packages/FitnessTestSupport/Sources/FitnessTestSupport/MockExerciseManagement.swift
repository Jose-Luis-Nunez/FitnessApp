import Foundation
import FitnessCore

@MainActor
public final class MockExerciseManagement: ExerciseManaging {
    public var exercisesByCategory: [MuscleCategoryGroup: [Exercise]] = [:]
    public var updatedExercises: [Exercise] = []
    public var resetExercises: [Exercise] = []

    public init() {}

    public func updateExercise(_ updatedExercise: Exercise, category: MuscleCategoryGroup) {
        updatedExercises.append(updatedExercise)
        guard var exercises = exercisesByCategory[category],
              let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) else { return }
        exercises[index] = updatedExercise
        exercisesByCategory[category] = exercises
    }

    public func getExercises(for category: MuscleCategoryGroup) -> [Exercise] {
        exercisesByCategory[category] ?? []
    }

    public func addExercise(_ exercise: Exercise, category: MuscleCategoryGroup, atTop: Bool) {
        var exercises = exercisesByCategory[category] ?? []
        if atTop { exercises.insert(exercise, at: 0) } else { exercises.append(exercise) }
        exercisesByCategory[category] = exercises
    }

    public func completeExercise(_ exercise: Exercise, category: MuscleCategoryGroup, setProgress: [SetProgress]) {
        var updated = exercise
        updated.isCompleted = true
        updateExercise(updated, category: category)
    }

    public func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        resetExercises.append(exercise)
        var updated = exercise
        updated.isCompleted = false
        updateExercise(updated, category: category)
    }

    public func resetAllExercises(for categories: [MuscleCategoryGroup]) {
        for category in categories {
            let exercises = exercisesByCategory[category] ?? []
            exercisesByCategory[category] = exercises.map {
                var e = $0; e.isCompleted = false; return e
            }
        }
    }

    public func getExerciseCount(for category: MuscleCategoryGroup) -> (total: Int, active: Int) {
        let exercises = exercisesByCategory[category] ?? []
        return (total: exercises.count, active: exercises.filter { !$0.isCompleted }.count)
    }

    public func getAllExerciseCounts(for categories: [MuscleCategoryGroup]) -> [MuscleCategoryGroup: (total: Int, active: Int)] {
        var result: [MuscleCategoryGroup: (total: Int, active: Int)] = [:]
        for cat in categories { result[cat] = getExerciseCount(for: cat) }
        return result
    }

    public func hasInactiveExercises(for categories: [MuscleCategoryGroup]) -> Bool {
        categories.contains { cat in
            (exercisesByCategory[cat] ?? []).contains { $0.isCompleted }
        }
    }
}
