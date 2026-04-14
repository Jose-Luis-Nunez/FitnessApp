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

    public func duplicateWorkout(_ workout: Workout) -> Workout { workout }
    public func deleteWorkout(_ workout: Workout) {}
    public func updateWorkout(_ workout: Workout) {}

    public func setCurrentWorkout(_ workout: Workout) { currentWorkout = workout }
    public func setAsDefaultWorkout(_ workout: Workout) { defaultWorkout = workout }
    public func removeAsDefaultWorkout() { defaultWorkout = nil }
    public func renameWorkout(_ workout: Workout, newName: String) {}
}
