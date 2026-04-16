import Foundation
import FitnessCore

@MainActor
public final class MockWorkoutStorage: WorkoutStoring {
    public var workouts: [Workout] = []
    public var currentWorkout: Workout?
    public var defaultWorkout: Workout?

    public init() {}

    public func createWorkout(name: String, selectedCategories: Set<MuscleCategoryGroup>) -> Workout {
        let workout = Workout(name: name, selectedCategories: selectedCategories)
        workouts.append(workout)
        return workout
    }

    public func duplicateWorkout(_ workout: Workout) -> Workout {
        let copy = Workout(name: "\(workout.name) Copy", selectedCategories: workout.selectedCategories)
        workouts.append(copy)
        return copy
    }

    public func deleteWorkout(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
        if currentWorkout?.id == workout.id { currentWorkout = workouts.first }
        if defaultWorkout?.id == workout.id { defaultWorkout = nil }
    }

    public func updateWorkout(_ workout: Workout) {
        if let idx = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[idx] = workout
        }
    }

    public func setCurrentWorkout(_ workout: Workout) { currentWorkout = workout }
    public func setAsDefaultWorkout(_ workout: Workout) { defaultWorkout = workout }
    public func removeAsDefaultWorkout() { defaultWorkout = nil }

    public func renameWorkout(_ workout: Workout, newName: String) {
        guard let idx = workouts.firstIndex(where: { $0.id == workout.id }) else { return }
        var updated = workouts[idx]
        updated.name = newName
        workouts[idx] = updated
        if currentWorkout?.id == workout.id { currentWorkout = updated }
        if defaultWorkout?.id == workout.id { defaultWorkout = updated }
    }
}
