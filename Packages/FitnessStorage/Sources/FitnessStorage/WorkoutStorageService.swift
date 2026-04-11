import Foundation
import Observation
import SwiftData
import FitnessCore
import Factory

@Observable
@MainActor
public final class WorkoutStorageService: WorkoutStoring {
    public var workouts: [Workout] = []
    public var currentWorkout: Workout?
    public var defaultWorkout: Workout?

    @ObservationIgnored
    private let context: ModelContext
    @ObservationIgnored
    private let userDefaults: UserDefaults
    @ObservationIgnored
    private let currentWorkoutKey = "current_workout_id"
    @ObservationIgnored
    private let defaultWorkoutKey = "default_workout_id"
    @ObservationIgnored
    private let exerciseStorage: ExerciseStoring

    public init(defaults: UserDefaults = .standard, exerciseStorage: ExerciseStoring? = nil) {
        self.exerciseStorage = exerciseStorage ?? Container.shared.exerciseStorage()
        let container = Container.shared.modelContainer()
        self.context = ModelContext(container)
        self.context.autosaveEnabled = true
        self.userDefaults = defaults
        reload()

        if workouts.isEmpty {
            let firstWorkout = Workout(name: "Workout 1")
            let model = WorkoutModel.from(firstWorkout, isDefault: true)
            context.insert(model)
            saveContext()
            workouts = [firstWorkout]
            currentWorkout = firstWorkout
            defaultWorkout = firstWorkout
            userDefaults.set(firstWorkout.id.uuidString, forKey: currentWorkoutKey)
            userDefaults.set(firstWorkout.id.uuidString, forKey: defaultWorkoutKey)
        }
    }

    public func createWorkout(name: String, selectedCategories: Set<MuscleCategoryGroup> = Set(MuscleCategoryGroup.allCases)) -> Workout {
        let newWorkout = Workout(name: name, selectedCategories: selectedCategories)
        let model = WorkoutModel.from(newWorkout)
        context.insert(model)
        saveContext()
        reload()
        return newWorkout
    }

    public func duplicateWorkout(_ workout: Workout) -> Workout {
        let duplicated = workout.copy(withName: "\(workout.name) Copy")
        let model = WorkoutModel.from(duplicated)
        context.insert(model)

        for category in workout.selectedCategories {
            let loaded = exerciseStorage.loadForWorkout(workoutId: workout.id, category: category)
            if !loaded.isEmpty {
                exerciseStorage.saveForWorkout(loaded, workoutId: duplicated.id, category: category)
            }
        }

        saveContext()
        reload()
        return duplicated
    }

    public func deleteWorkout(_ workout: Workout) {
        let workoutId = workout.id
        var descriptor = FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.id == workoutId }
        )
        descriptor.fetchLimit = 1

        if let model = try? context.fetch(descriptor).first {
            context.delete(model)
            saveContext()
        }

        if currentWorkout?.id == workout.id {
            reload()
            currentWorkout = workouts.first
            if let cw = currentWorkout {
                userDefaults.set(cw.id.uuidString, forKey: currentWorkoutKey)
            } else {
                userDefaults.removeObject(forKey: currentWorkoutKey)
            }
        } else {
            reload()
        }
    }

    public func updateWorkout(_ workout: Workout) {
        let workoutId = workout.id
        var descriptor = FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.id == workoutId }
        )
        descriptor.fetchLimit = 1

        if let model = try? context.fetch(descriptor).first {
            model.name = workout.name
            model.selectedCategories = workout.selectedCategories.map(\.rawValue)
            model.lastModified = Date()
            saveContext()
            reload()
        }
    }

    public func setCurrentWorkout(_ workout: Workout) {
        currentWorkout = workout
        userDefaults.set(workout.id.uuidString, forKey: currentWorkoutKey)
    }

    public func setAsDefaultWorkout(_ workout: Workout) {
        let allId = workout.id
        if let allModels = try? context.fetch(FetchDescriptor<WorkoutModel>()) {
            for m in allModels { m.isDefault = (m.id == allId) }
        }
        saveContext()
        defaultWorkout = workout
        userDefaults.set(workout.id.uuidString, forKey: defaultWorkoutKey)
    }

    public func removeAsDefaultWorkout() {
        if let allModels = try? context.fetch(FetchDescriptor<WorkoutModel>()) {
            for m in allModels { m.isDefault = false }
        }
        saveContext()
        defaultWorkout = nil
        userDefaults.removeObject(forKey: defaultWorkoutKey)
    }

    public func renameWorkout(_ workout: Workout, newName: String) {
        let workoutId = workout.id
        var descriptor = FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.id == workoutId }
        )
        descriptor.fetchLimit = 1

        if let model = try? context.fetch(descriptor).first {
            model.name = newName
            model.lastModified = Date()
            saveContext()
            reload()
        }
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("WorkoutStorageService: Failed to save context: \(error)")
        }
    }

    private func reload() {
        let descriptor = FetchDescriptor<WorkoutModel>(
            sortBy: [SortDescriptor(\.createdDate)]
        )

        let models = (try? context.fetch(descriptor)) ?? []
        workouts = models.map { $0.toDomain() }

        let currentId = userDefaults.string(forKey: currentWorkoutKey)
            .flatMap(UUID.init(uuidString:))
        currentWorkout = workouts.first { $0.id == currentId } ?? workouts.first

        let defaultId = userDefaults.string(forKey: defaultWorkoutKey)
            .flatMap(UUID.init(uuidString:))
        defaultWorkout = workouts.first { $0.id == defaultId }
    }
}
