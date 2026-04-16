import Foundation
import SwiftUI
import Observation
import FitnessCore
import FitnessStorage
import Factory

@Observable
@MainActor
public final class WorkoutsViewModel {
    public var showingFABOptions = false
    public var showingCreateWorkoutFullScreen = false
    public var showingRenameWorkout = false
    public var showingDeleteConfirmation = false
    public var selectedWorkoutForAction: Workout?
    public var newWorkoutName = ""
    public var renameWorkoutName = ""
    public var selectedMuscleGroups: Set<MuscleCategoryGroup> = []

    @ObservationIgnored private let storageService: WorkoutStoring
    @ObservationIgnored private let exerciseStorageService: ExerciseStoring
    @ObservationIgnored private let deleteWorkoutUseCase: DeleteWorkoutUseCase
    @ObservationIgnored private let duplicateWorkoutUseCase: DuplicateWorkoutUseCase

    public var workouts: [Workout] { storageService.workouts }
    public var currentWorkout: Workout? { storageService.currentWorkout }
    public var defaultWorkout: Workout? { storageService.defaultWorkout }

    /// Designated initializer. Dependencies default to the Factory container registrations
    /// in production; tests pass explicit mocks for isolation (no `Container.shared` coupling).
    public init(
        workoutStorage: WorkoutStoring? = nil,
        exerciseStorage: ExerciseStoring? = nil,
        deleteWorkoutUseCase: DeleteWorkoutUseCase? = nil,
        duplicateWorkoutUseCase: DuplicateWorkoutUseCase? = nil
    ) {
        self.storageService = workoutStorage ?? Container.shared.workoutStorage()
        self.exerciseStorageService = exerciseStorage ?? Container.shared.exerciseStorage()
        self.deleteWorkoutUseCase = deleteWorkoutUseCase ?? Container.shared.deleteWorkoutUseCase()
        self.duplicateWorkoutUseCase = duplicateWorkoutUseCase ?? Container.shared.duplicateWorkoutUseCase()
    }

    // MARK: - Workout Actions

    public func createNewWorkout() {
        guard !newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let workout = storageService.createWorkout(name: newWorkoutName, selectedCategories: selectedMuscleGroups)
        storageService.setCurrentWorkout(workout)

        newWorkoutName = ""
        selectedMuscleGroups = []
        showingCreateWorkoutFullScreen = false
    }

    public func selectWorkout(_ workout: Workout) {
        storageService.setCurrentWorkout(workout)
    }

    public func duplicateWorkout(_ workout: Workout) {
        let duplicatedWorkout = duplicateWorkoutUseCase.execute(workout)
        storageService.setCurrentWorkout(duplicatedWorkout)
        showingFABOptions = false
    }

    /// Deletes the workout. Enforces the invariant that at least one workout must remain —
    /// matches the UI affordance `canDeleteWorkout` so the rule lives in exactly one place.
    public func deleteWorkout(_ workout: Workout) {
        guard canDeleteWorkout else { return }
        deleteWorkoutUseCase.execute(workout)
        showingFABOptions = false
    }

    public func renameWorkout() {
        guard let workout = selectedWorkoutForAction,
              !renameWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        storageService.renameWorkout(workout, newName: renameWorkoutName)

        renameWorkoutName = ""
        showingRenameWorkout = false
        selectedWorkoutForAction = nil
    }

    // MARK: - UI Actions

    public func showFABOptions(for workout: Workout) {
        selectedWorkoutForAction = workout
        showingFABOptions = true
    }

    public func showCreateWorkout() {
        newWorkoutName = "Workout \(workouts.count + 1)"
        selectedMuscleGroups = []
        showingCreateWorkoutFullScreen = true
    }

    public func toggleMuscleGroup(_ group: MuscleCategoryGroup) {
        if selectedMuscleGroups.contains(group) {
            selectedMuscleGroups.remove(group)
        } else {
            selectedMuscleGroups.insert(group)
        }
    }

    public func isMuscleGroupSelected(_ group: MuscleCategoryGroup) -> Bool {
        selectedMuscleGroups.contains(group)
    }

    public func showRenameWorkout(for workout: Workout) {
        selectedWorkoutForAction = workout
        renameWorkoutName = workout.name
        showingRenameWorkout = true
        showingFABOptions = false
    }

    public func hideFABOptions() {
        showingFABOptions = false
        showingDeleteConfirmation = false
        selectedWorkoutForAction = nil
    }

    public func showDeleteConfirmation() {
        showingDeleteConfirmation = true
    }

    public func confirmDelete() {
        if let workout = selectedWorkoutForAction {
            deleteWorkout(workout)
        }
        hideFABOptions()
    }

    public func cancelDelete() {
        showingDeleteConfirmation = false
    }

    // MARK: - Queries

    public var canDeleteWorkout: Bool {
        workouts.count > 1
    }

    public func isDefaultWorkout(_ workout: Workout) -> Bool {
        defaultWorkout?.id == workout.id
    }

    public func setAsDefault(_ workout: Workout) {
        storageService.setAsDefaultWorkout(workout)
    }

    public func removeAsDefault() {
        storageService.removeAsDefaultWorkout()
    }

    public func getExerciseCount(for workout: Workout) -> Int {
        var totalCount = 0

        for category in MuscleCategoryGroup.allCases {
            let exercises = exerciseStorageService.loadForWorkout(workoutId: workout.id, category: category)
            totalCount += exercises.count
        }

        return totalCount
    }
}
