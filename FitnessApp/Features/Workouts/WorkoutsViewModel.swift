import Foundation
import SwiftUI

class WorkoutsViewModel: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var currentWorkout: Workout?
    @Published var defaultWorkout: Workout?
    @Published var showingFABOptions = false
    @Published var showingCreateWorkout = false
    @Published var showingCreateWorkoutFullScreen = false
    @Published var showingRenameWorkout = false
    @Published var showingDeleteConfirmation = false
    @Published var selectedWorkoutForAction: Workout?
    @Published var newWorkoutName = ""
    @Published var renameWorkoutName = ""
    @Published var selectedMuscleGroups: Set<MuscleCategoryGroup> = []
    
    private let storageService = WorkoutStorageService.shared
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        storageService.$workouts
            .assign(to: &$workouts)
        
        storageService.$currentWorkout
            .assign(to: &$currentWorkout)
        
        storageService.$defaultWorkout
            .assign(to: &$defaultWorkout)
    }
    
    // MARK: - Workout Actions
    
    func createNewWorkout() {
        guard !newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let workout = storageService.createWorkout(name: newWorkoutName, selectedCategories: selectedMuscleGroups)
        storageService.setCurrentWorkout(workout)
        
        newWorkoutName = ""
        selectedMuscleGroups = []
        showingCreateWorkoutFullScreen = false
    }
    
    func selectWorkout(_ workout: Workout) {
        storageService.setCurrentWorkout(workout)
    }
    
    func duplicateWorkout(_ workout: Workout) {
        let duplicatedWorkout = storageService.duplicateWorkout(workout)
        storageService.setCurrentWorkout(duplicatedWorkout)
        showingFABOptions = false
    }
    
    func deleteWorkout(_ workout: Workout) {
        storageService.deleteWorkout(workout)
        showingFABOptions = false
    }
    
    func renameWorkout() {
        guard let workout = selectedWorkoutForAction,
              !renameWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        storageService.renameWorkout(workout, newName: renameWorkoutName)
        
        renameWorkoutName = ""
        showingRenameWorkout = false
        selectedWorkoutForAction = nil
    }
    
    // MARK: - UI Actions
    
    func showFABOptions(for workout: Workout) {
        selectedWorkoutForAction = workout
        showingFABOptions = true
    }
    
    func showCreateWorkout() {
        newWorkoutName = "Workout \(workouts.count + 1)"
        selectedMuscleGroups = [] // Default: no categories selected
        showingCreateWorkoutFullScreen = true
    }
    
    func toggleMuscleGroup(_ group: MuscleCategoryGroup) {
        if selectedMuscleGroups.contains(group) {
            selectedMuscleGroups.remove(group)
        } else {
            selectedMuscleGroups.insert(group)
        }
    }
    
    func isMuscleGroupSelected(_ group: MuscleCategoryGroup) -> Bool {
        selectedMuscleGroups.contains(group)
    }
    
    func showRenameWorkout(for workout: Workout) {
        selectedWorkoutForAction = workout
        renameWorkoutName = workout.name
        showingRenameWorkout = true
        showingFABOptions = false
    }
    
    func hideFABOptions() {
        showingFABOptions = false
        showingDeleteConfirmation = false
        selectedWorkoutForAction = nil
    }
    
    func showDeleteConfirmation() {
        showingDeleteConfirmation = true
    }
    
    func confirmDelete() {
        if let workout = selectedWorkoutForAction {
            deleteWorkout(workout)
        }
        hideFABOptions()
    }
    
    func cancelDelete() {
        showingDeleteConfirmation = false
    }
    
    // MARK: - Computed Properties
    
    var isCurrentWorkout: (Workout) -> Bool {
        return { workout in
            self.currentWorkout?.id == workout.id
        }
    }
    
    var canDeleteWorkout: Bool {
        return workouts.count > 1
    }
    
    var isDefaultWorkout: (Workout) -> Bool {
        return { workout in
            self.defaultWorkout?.id == workout.id
        }
    }
    
    func setAsDefault(_ workout: Workout) {
        storageService.setAsDefaultWorkout(workout)
    }
    
    func removeAsDefault() {
        storageService.removeAsDefaultWorkout()
    }
    
    func getExerciseCount(for workout: Workout) -> Int {
        let exerciseService = ExerciseStorageService()
        var totalCount = 0
        
        for category in MuscleCategoryGroup.allCases {
            let exercises = exerciseService.loadForWorkout(workoutId: workout.id, category: category)
            totalCount += exercises.count
        }
        
        return totalCount
    }
} 