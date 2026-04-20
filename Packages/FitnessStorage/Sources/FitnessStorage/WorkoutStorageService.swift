import Foundation
import Observation
import os
import SwiftData
import FitnessCore
import Factory

private let logger = Logger(subsystem: "FitnessStorage", category: "WorkoutStorageService")

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

    public init(container: ModelContainer? = nil, defaults: UserDefaults = .standard, exerciseStorage: ExerciseStoring) {
        self.exerciseStorage = exerciseStorage
        let resolved = container ?? Container.shared.modelContainer()
        self.context = ModelContext(resolved)
        self.context.autosaveEnabled = true
        self.userDefaults = defaults

        // Two-phase startup. Phase 1 repairs any inherited inconsistency from
        // the pre-fix legacy-import startup race, where the service was eagerly
        // resolved before the JSON → SwiftData import landed and seeded an
        // empty auto-default that later sat on top of the imported workouts.
        // Phase 2 is the genuine cold-start path where we seed an initial
        // workout for brand-new installs.
        healInheritedAutoDefaultIfNeeded()
        reload()
        seedFirstWorkoutIfStoreIsEmpty()
    }

    /// Repairs the corruption shape produced by the pre-fix legacy-import
    /// startup race: a service-created auto-default workout (`name ==
    /// defaultAutoWorkoutName`, `isDefault == true`, **no exercises**, **no
    /// analytics**) sitting next to the user's real, populated workouts that
    /// were imported afterwards. We
    /// can recognise this only by structure — name + emptiness + the presence
    /// of other workouts. Heuristic, but bounded: a deliberate, populated
    /// "Workout 1" is never deleted, and a brand-new install (only the auto
    /// workout, nothing else) is left untouched so phase 2 doesn't re-seed.
    private func healInheritedAutoDefaultIfNeeded() {
        let descriptor = FetchDescriptor<WorkoutModel>()
        let allModels: [WorkoutModel]
        do {
            allModels = try context.fetch(descriptor)
        } catch {
            logger.error("Heal: failed to fetch workouts, skipping repair: \(error)")
            return
        }

        guard allModels.count > 1 else { return }

        // Heuristic uses **four** simultaneous markers — all four must hold to
        // flag a workout as service-seeded auto-default. Any one of them
        // failing leaves the workout untouched, biased toward false-negatives
        // (better to leave one orphan empty workout than to delete a user's
        // legitimate one).
        //
        //   1. `name == "Workout 1"` — the literal string the seeder uses.
        //   2. `exercises.isEmpty` — service seed never has exercises; a user
        //      who removed all exercises but kept the workout shell is rare
        //      enough that we accept the false-positive risk in that corner.
        //   3. `isDefault == true` — `createWorkout(name:)` and `duplicate`
        //      both create with `isDefault = false`; only the seeder and the
        //      explicit `setAsDefaultWorkout` user gesture set `true`. A user
        //      who seeded "Workout 1" themselves and then explicitly made it
        //      default has a structurally identical row to the seed — but
        //      criterion (4) still discriminates.
        //   4. Strictly newer than at least one other workout. The seed runs
        //      on every cold start; if it wins the race against an import,
        //      the imported rows carry their original (years-old) createdDate
        //      and the seed carries `now`. A user creating "Workout 1" today
        //      always creates it *as the latest* row, so this guard fires
        //      false only if they *first* deleted an older workout — and even
        //      then they'd see the "current → Workout 1" log line.
        let candidates = allModels.filter {
            $0.name == Self.defaultAutoWorkoutName && $0.exercises.isEmpty && $0.isDefault
        }
        guard !candidates.isEmpty else { return }
        let suspects = candidates.filter { candidate in
            allModels.contains { other in other !== candidate && other.createdDate < candidate.createdDate }
        }
        guard !suspects.isEmpty else { return }
        let realWorkouts = allModels.filter { !suspects.contains($0) }
        guard !realWorkouts.isEmpty else { return }

        let suspectIds = Set(suspects.map(\.id))
        let currentId = userDefaults.string(forKey: currentWorkoutKey).flatMap(UUID.init(uuidString:))
        let defaultId = userDefaults.string(forKey: defaultWorkoutKey).flatMap(UUID.init(uuidString:))

        let preferredFallback = realWorkouts.first { $0.isDefault } ?? realWorkouts.sorted { $0.createdDate < $1.createdDate }.first!

        for suspect in suspects {
            context.delete(suspect)
        }
        if !realWorkouts.contains(where: { $0.isDefault }) {
            preferredFallback.isDefault = true
        }
        if let currentId, suspectIds.contains(currentId) {
            userDefaults.set(preferredFallback.id.uuidString, forKey: currentWorkoutKey)
        }
        if let defaultId, suspectIds.contains(defaultId) {
            userDefaults.set(preferredFallback.id.uuidString, forKey: defaultWorkoutKey)
        }
        saveContext()

        logger.notice("Heal: removed \(suspects.count, privacy: .public) empty auto-default workout(s); \(realWorkouts.count, privacy: .public) real workouts retained; current → \(preferredFallback.name, privacy: .public).")
    }

    private func seedFirstWorkoutIfStoreIsEmpty() {
        guard workouts.isEmpty else { return }

        let firstWorkout = Workout(name: Self.defaultAutoWorkoutName)
        let model = WorkoutModel.from(firstWorkout, isDefault: true)
        context.insert(model)
        saveContext()
        workouts = [firstWorkout]
        currentWorkout = firstWorkout
        defaultWorkout = firstWorkout
        userDefaults.set(firstWorkout.id.uuidString, forKey: currentWorkoutKey)
        userDefaults.set(firstWorkout.id.uuidString, forKey: defaultWorkoutKey)
    }

    /// The literal name the cold-start seed uses. Centralised so the heal
    /// detector and the seeder agree on the marker. NEVER localise this — the
    /// healer matches on it byte-for-byte to distinguish a service-created
    /// default from a user-created workout that happens to have the same name.
    @ObservationIgnored
    private static let defaultAutoWorkoutName = "Workout 1"

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

        do {
            if let model = try context.fetch(descriptor).first {
                context.delete(model)
                saveContext()
            }
        } catch {
            logger.error("Failed to fetch workout for deletion \(workoutId): \(error)")
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

        do {
            if let model = try context.fetch(descriptor).first {
                model.name = workout.name
                model.selectedCategories = workout.selectedCategories.map(\.rawValue)
                model.lastModified = Date()
                saveContext()
                reload()
            }
        } catch {
            logger.error("Failed to fetch workout for update \(workoutId): \(error)")
        }
    }

    public func setCurrentWorkout(_ workout: Workout) {
        currentWorkout = workout
        userDefaults.set(workout.id.uuidString, forKey: currentWorkoutKey)
    }

    public func setAsDefaultWorkout(_ workout: Workout) {
        let allId = workout.id
        do {
            let allModels = try context.fetch(FetchDescriptor<WorkoutModel>())
            for m in allModels { m.isDefault = (m.id == allId) }
        } catch {
            logger.error("Failed to fetch workouts for default assignment: \(error)")
        }
        saveContext()
        defaultWorkout = workout
        userDefaults.set(workout.id.uuidString, forKey: defaultWorkoutKey)
    }

    public func removeAsDefaultWorkout() {
        do {
            let allModels = try context.fetch(FetchDescriptor<WorkoutModel>())
            for m in allModels { m.isDefault = false }
        } catch {
            logger.error("Failed to fetch workouts for default removal: \(error)")
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

        do {
            if let model = try context.fetch(descriptor).first {
                model.name = newName
                model.lastModified = Date()
                saveContext()
                reload()
            }
        } catch {
            logger.error("Failed to fetch workout for rename \(workoutId): \(error)")
        }
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save context: \(error)")
        }
    }

    private func reload() {
        let descriptor = FetchDescriptor<WorkoutModel>(
            sortBy: [SortDescriptor(\.createdDate)]
        )

        do {
            let models = try context.fetch(descriptor)
            workouts = models.map { $0.toDomain() }
        } catch {
            logger.error("Failed to fetch workouts during reload: \(error)")
            workouts = []
        }

        let currentId = userDefaults.string(forKey: currentWorkoutKey)
            .flatMap(UUID.init(uuidString:))
        currentWorkout = workouts.first { $0.id == currentId } ?? workouts.first

        let defaultId = userDefaults.string(forKey: defaultWorkoutKey)
            .flatMap(UUID.init(uuidString:))
        defaultWorkout = workouts.first { $0.id == defaultId }
    }
}
