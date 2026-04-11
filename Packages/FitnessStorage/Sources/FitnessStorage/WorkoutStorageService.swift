import Foundation
import Observation
import FitnessCore
import Factory

@Observable
@MainActor
public final class WorkoutStorageService: WorkoutStoring {
    public var workouts: [Workout] = []
    public var currentWorkout: Workout?
    public var defaultWorkout: Workout?

    private let userDefaults = UserDefaults.standard
    private let workoutsKey = "stored_workouts"
    private let currentWorkoutKey = "current_workout_id"
    private let defaultWorkoutKey = "default_workout_id"

    public init() {
        loadWorkouts()
        loadCurrentWorkout()
        loadDefaultWorkout()

        if workouts.isEmpty {
            let firstWorkout = Workout(name: "Workout 1")
            workouts.append(firstWorkout)
            currentWorkout = firstWorkout
            defaultWorkout = firstWorkout
            saveWorkouts()
            saveCurrentWorkout()
            saveDefaultWorkout()
        }
    }

    public func createWorkout(name: String, selectedCategories: Set<MuscleCategoryGroup> = Set(MuscleCategoryGroup.allCases)) -> Workout {
        let newWorkout = Workout(name: name, selectedCategories: selectedCategories)
        workouts.append(newWorkout)
        saveWorkouts()
        return newWorkout
    }

    public func duplicateWorkout(_ workout: Workout) -> Workout {
        let duplicatedWorkout = workout.copy(withName: "\(workout.name) Copy")
        workouts.append(duplicatedWorkout)
        saveWorkouts()

        let exercises = Container.shared.exerciseStorage()
        for category in workout.selectedCategories {
            let loaded = exercises.loadForWorkout(workoutId: workout.id, category: category)
            if !loaded.isEmpty {
                exercises.saveForWorkout(loaded, workoutId: duplicatedWorkout.id, category: category)
            }
        }

        return duplicatedWorkout
    }

    public func deleteWorkout(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }

        if currentWorkout?.id == workout.id {
            currentWorkout = workouts.first
            saveCurrentWorkout()
        }

        saveWorkouts()
    }

    public func updateWorkout(_ workout: Workout) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            var updatedWorkout = workout
            updatedWorkout.updateLastModified()
            workouts[index] = updatedWorkout

            if currentWorkout?.id == workout.id {
                currentWorkout = updatedWorkout
            }

            saveWorkouts()
        }
    }

    public func setCurrentWorkout(_ workout: Workout) {
        currentWorkout = workout
        saveCurrentWorkout()
    }

    public func setAsDefaultWorkout(_ workout: Workout) {
        defaultWorkout = workout
        saveDefaultWorkout()
    }

    public func removeAsDefaultWorkout() {
        defaultWorkout = nil
        userDefaults.removeObject(forKey: defaultWorkoutKey)
    }

    public func renameWorkout(_ workout: Workout, newName: String) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index].name = newName
            workouts[index].updateLastModified()

            if currentWorkout?.id == workout.id {
                currentWorkout = workouts[index]
            }

            saveWorkouts()
        }
    }

    public func updateExerciseData(for workoutId: UUID, key: String, data: Any) {
        if let index = workouts.firstIndex(where: { $0.id == workoutId }) {
            workouts[index].exerciseData[key] = data
            workouts[index].updateLastModified()

            if currentWorkout?.id == workoutId {
                currentWorkout = workouts[index]
            }

            saveWorkouts()
        }
    }

    public func getExerciseData(for workoutId: UUID, key: String) -> Any? {
        return workouts.first(where: { $0.id == workoutId })?.exerciseData[key]
    }

    private func saveWorkouts() {
        if let encoded = try? JSONEncoder().encode(workouts) {
            userDefaults.set(encoded, forKey: workoutsKey)
        }
    }

    private func loadWorkouts() {
        if let data = userDefaults.data(forKey: workoutsKey),
           let decoded = try? JSONDecoder().decode([Workout].self, from: data) {
            workouts = decoded
        }
    }

    private func saveCurrentWorkout() {
        if let currentWorkout = currentWorkout {
            userDefaults.set(currentWorkout.id.uuidString, forKey: currentWorkoutKey)
        }
    }

    private func loadCurrentWorkout() {
        if let currentWorkoutIdString = userDefaults.string(forKey: currentWorkoutKey),
           let currentWorkoutId = UUID(uuidString: currentWorkoutIdString) {
            currentWorkout = workouts.first(where: { $0.id == currentWorkoutId })
        }
    }

    private func saveDefaultWorkout() {
        if let defaultWorkout = defaultWorkout {
            userDefaults.set(defaultWorkout.id.uuidString, forKey: defaultWorkoutKey)
        }
    }

    private func loadDefaultWorkout() {
        if let defaultWorkoutIdString = userDefaults.string(forKey: defaultWorkoutKey),
           let defaultWorkoutId = UUID(uuidString: defaultWorkoutIdString) {
            defaultWorkout = workouts.first(where: { $0.id == defaultWorkoutId })
        }
    }
}
