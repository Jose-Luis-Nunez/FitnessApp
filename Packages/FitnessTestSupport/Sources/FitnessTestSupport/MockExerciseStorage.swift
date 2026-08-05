import Foundation
import FitnessCore

@MainActor
public final class MockExerciseStorage: ExerciseStoring {
    public var exercisesByCategory: [MuscleCategoryGroup: [Exercise]] = [:]
    public var loadForWorkoutHandler: ((UUID, MuscleCategoryGroup) -> [Exercise])?
    public private(set) var saveForWorkoutCallCount = 0
    public private(set) var workoutWideLoadCallCount = 0
    public private(set) var requestedWorkoutIDs: [UUID] = []
    public private(set) var updatedExercises: [Exercise] = []
    private var countsByWorkout: [UUID: [MuscleCategoryGroup: Int]] = [:]
    /// Authoritative state for workout-scoped fixtures. `exercisesByCategory`
    /// remains the compatibility fallback for older category-only tests.
    private var exercisesByWorkout: [UUID: [MuscleCategoryGroup: [Exercise]]] = [:]

    public init() {}

    public func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise] {
        if let loadForWorkoutHandler {
            return loadForWorkoutHandler(workoutId, category)
        }
        if !exercisesByWorkout.isEmpty {
            return exercisesByWorkout[workoutId]?[category] ?? []
        }
        return exercisesByCategory[category] ?? []
    }

    public func loadWorkoutExercises(for workoutId: UUID) throws -> [Exercise] {
        workoutWideLoadCallCount += 1
        requestedWorkoutIDs.append(workoutId)
        return MuscleCategoryGroup.allCases.flatMap {
            loadForWorkout(workoutId: workoutId, category: $0)
        }
    }

    public func seedExercises(_ exercises: [Exercise], workoutId: UUID) {
        let grouped = Dictionary(grouping: exercises, by: \.category)
        exercisesByWorkout[workoutId] = grouped
        countsByWorkout[workoutId] = grouped.mapValues(\.count)
    }

    public func exerciseCountsByWorkout() -> [UUID: Int] {
        countsByWorkout.mapValues { counts in
            counts.values.reduce(0, +)
        }
    }

    public func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        saveForWorkoutCallCount += 1
        exercisesByCategory[category] = exercises
        exercisesByWorkout[workoutId, default: [:]][category] = exercises
        countsByWorkout[workoutId, default: [:]][category] = exercises.count
    }

    public func updateExercise(_ exercise: Exercise) {
        updatedExercises.append(exercise)
        _ = replaceExercise(exercise, in: &exercisesByCategory)

        for workoutId in Array(exercisesByWorkout.keys) {
            guard var scoped = exercisesByWorkout[workoutId],
                  replaceExercise(exercise, in: &scoped) else { continue }
            exercisesByWorkout[workoutId] = scoped
            countsByWorkout[workoutId] = scoped.mapValues(\.count)
        }
    }

    @discardableResult
    private func replaceExercise(
        _ exercise: Exercise,
        in exercisesByCategory: inout [MuscleCategoryGroup: [Exercise]]
    ) -> Bool {
        for category in MuscleCategoryGroup.allCases {
            guard let index = exercisesByCategory[category]?.firstIndex(where: {
                $0.id == exercise.id
            }) else { continue }

            if category == exercise.category {
                exercisesByCategory[category]?[index] = exercise
            } else {
                exercisesByCategory[category]?.remove(at: index)
                exercisesByCategory[exercise.category, default: []].append(exercise)
            }
            return true
        }
        return false
    }
}
