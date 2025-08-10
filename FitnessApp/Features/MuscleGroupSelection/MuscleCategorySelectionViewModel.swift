import Foundation
import Combine

class MuscleCategorySelectionViewModel: ObservableObject {
    @Published var categories: [MuscleCategoryGroup] = []
    @Published var bottomBarViewModel: BottomActionBarViewModel
    @Published var currentWorkoutName: String = "Dein Workout"

    private let storageService = ExerciseStorageService()
    private let workoutStorageService = WorkoutStorageService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published private var exerciseCounts: [MuscleCategoryGroup: (total: Int, active: Int)] = [:]

    init() {
        self.bottomBarViewModel = BottomActionBarViewModel(
            isSetInProgress: false,
            currentSet: 0,
            currentExercise: nil,
            hasActiveExercise: false,
            exercises: [],
            isLastSetCompleted: false,
            quickDoneModeActive: false,
            quickDoneAllCompleted: false,
            didEditCompleteSet: false,
            didJustEditSet: false,
            showResetAllExercisesButton: false
        )
        updateExerciseCountsAndViewModel()
        updateWorkoutName(workoutStorageService.currentWorkout)
        
        // Listen to workout changes
        workoutStorageService.$currentWorkout
            .sink { [weak self] currentWorkout in
                self?.updateCategories(for: currentWorkout)
                self?.updateExerciseCountsAndViewModel()
                self?.updateWorkoutName(currentWorkout)
            }
            .store(in: &cancellables)
        
        // Initialize categories for current workout
        updateCategories(for: workoutStorageService.currentWorkout)
    }

    func resetAllExercises() {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return }
        
        for (_, activeSetVM) in SessionTrainingCache.shared.activeSetVMs {
            activeSetVM.cancelActiveSet()
        }

        for group in MuscleCategoryGroup.allCases {
            let exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: group)
            let updatedExercises = exercises.map { exercise in
                var updatedExercise = exercise
                updatedExercise.isCompleted = false
                return updatedExercise
            }
            storageService.saveForWorkout(updatedExercises, workoutId: currentWorkout.id, category: group)
        }
        updateExerciseCountsAndViewModel()
    }

    func updateExerciseCounts() {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return }
        
        for group in MuscleCategoryGroup.allCases {
            let exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: group)
            exerciseCounts[group] = (total: exercises.count, active: exercises.filter { !$0.isCompleted }.count)
        }
    }
    
    func getExerciseCount(for group: MuscleCategoryGroup) -> (total: Int, active: Int)? {
        exerciseCounts[group]
    }

    func hasInactiveExercises() -> Bool {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return false }
        
        for group in MuscleCategoryGroup.allCases {
            let exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: group)
            if exercises.contains(where: { !$0.isCompleted }) {
                return true
            }
        }
        return false
    }

    private func updateExerciseCountsAndViewModel() {
        updateExerciseCounts()
        bottomBarViewModel = BottomActionBarViewModel(
            isSetInProgress: false,
            currentSet: 0,
            currentExercise: nil,
            hasActiveExercise: false,
            exercises: [],
            isLastSetCompleted: false,
            quickDoneModeActive: false,
            quickDoneAllCompleted: false,
            didEditCompleteSet: false,
            didJustEditSet: false,
            showResetAllExercisesButton: hasInactiveExercises()
        )
    }
    
    func hasActiveSetForCategory(_ group: MuscleCategoryGroup) -> Bool {
        return SessionTrainingCache.shared.activeSetVMs.values.contains { $0.category == group && $0.isSetInProgress }
    }
    
    private func updateCategories(for workout: Workout?) {
        if let workout = workout {
            categories = Array(workout.selectedCategories).sorted { $0.rawValue < $1.rawValue }
        } else {
            categories = []
        }
    }
    
    private func updateWorkoutName(_ workout: Workout?) {
        currentWorkoutName = workout?.name ?? "Dein Workout"
    }
}
