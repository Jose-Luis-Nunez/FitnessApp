import Foundation
import Mockable

@Mockable
@MainActor
public protocol WorkoutStoring: AnyObject {
    var workouts: [Workout] { get set }
    var currentWorkout: Workout? { get set }
    var defaultWorkout: Workout? { get set }

    func createWorkout(name: String, selectedCategories: Set<MuscleCategoryGroup>) -> Workout
    func duplicateWorkout(_ workout: Workout) -> Workout
    func deleteWorkout(_ workout: Workout)
    func updateWorkout(_ workout: Workout)
    func setCurrentWorkout(_ workout: Workout)
    func setAsDefaultWorkout(_ workout: Workout)
    func removeAsDefaultWorkout()
    func renameWorkout(_ workout: Workout, newName: String)
}
