import Foundation
import Combine

/// Shared service to manage exercise operations and eliminate duplicate logic
/// between MuscleCategoryViewModel and MuscleCategorySelectionViewModel
class ExerciseManagementService: ObservableObject {
    private let storageService: ExerciseStorageService
    private let analyticsViewModel: AnalyticsViewModel
    private let workoutStorageService = WorkoutStorageService.shared
    
    init() {
        self.storageService = ExerciseStorageService()
        self.analyticsViewModel = AnalyticsViewModel()
    }
    
    // MARK: - Exercise CRUD Operations
    
    func updateExercise(_ updatedExercise: Exercise, category: MuscleCategoryGroup) {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return }
        var exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: category)
        if let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            exercises[index] = updatedExercise
            saveExercises(exercises, workoutId: currentWorkout.id, category: category)
        }
    }
    
    func getExercises(for category: MuscleCategoryGroup) -> [Exercise] {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return [] }
        return storageService.loadForWorkout(workoutId: currentWorkout.id, category: category)
    }
    
    func addExercise(_ exercise: Exercise, category: MuscleCategoryGroup, atTop: Bool = false) {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return }
        var exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: category)
        
        if atTop {
            exercises.insert(exercise, at: 0)
        } else {
            exercises.append(exercise)
        }
        
        saveExercises(exercises, workoutId: currentWorkout.id, category: category)
    }
    
    // MARK: - Exercise State Management
    
    func completeExercise(_ exercise: Exercise, category: MuscleCategoryGroup, setProgress: [SetProgress]) {
        var updatedExercise = exercise
        updatedExercise.isCompleted = true
        updateExercise(updatedExercise, category: category)
        saveAnalytics(exerciseId: exercise.id, setProgress: setProgress)
    }
    
    func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        var updatedExercise = exercise
        updatedExercise.isCompleted = false
        updateExercise(updatedExercise, category: category)
    }
    
    func resetAllExercises(for categories: [MuscleCategoryGroup]) {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return }
        
        for category in categories {
            let exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: category)
            let updatedExercises = exercises.map { exercise in
                var updatedExercise = exercise
                updatedExercise.isCompleted = false
                return updatedExercise
            }
            saveExercises(updatedExercises, workoutId: currentWorkout.id, category: category)
        }
    }
    
    // MARK: - Analytics
    
    func saveAnalytics(exerciseId: UUID, setProgress: [SetProgress]) {
        analyticsViewModel.saveAnalytics(
            exerciseId: exerciseId,
            setProgress: setProgress
        )
    }
    
    // MARK: - Storage
    
    private func saveExercises(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        if storageService.hasUserId {
            storageService.saveForWorkout(exercises, workoutId: workoutId, category: category)
        } else {
            print("No userId available, skipping save")
        }
    }
    
    // MARK: - Statistics
    
    func getExerciseCount(for category: MuscleCategoryGroup) -> (total: Int, active: Int) {
        let exercises = getExercises(for: category)
        return (total: exercises.count, active: exercises.filter { !$0.isCompleted }.count)
    }
    
    func getAllExerciseCounts(for categories: [MuscleCategoryGroup]) -> [MuscleCategoryGroup: (total: Int, active: Int)] {
        var counts: [MuscleCategoryGroup: (total: Int, active: Int)] = [:]
        for category in categories {
            counts[category] = getExerciseCount(for: category)
        }
        return counts
    }
    
    func hasInactiveExercises(for categories: [MuscleCategoryGroup]) -> Bool {
        for category in categories {
            let exercises = getExercises(for: category)
            if exercises.contains(where: { !$0.isCompleted }) {
                return true
            }
        }
        return false
    }
}
