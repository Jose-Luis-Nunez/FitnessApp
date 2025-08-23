import Foundation
import Combine

class MuscleCategorySelectionViewModel: ObservableObject {
    @Published var categories: [MuscleCategoryGroup] = []
    @Published var bottomBarViewModel: BottomActionBarViewModel
    @Published var currentWorkoutName: String = "Dein Workout"

    private let exerciseManagementService = ExerciseManagementService()
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

        exerciseManagementService.resetAllExercises(for: MuscleCategoryGroup.allCases)
        updateExerciseCountsAndViewModel()
    }

    func updateExerciseCounts() {
        exerciseCounts = exerciseManagementService.getAllExerciseCounts(for: MuscleCategoryGroup.allCases)
    }
    
    func getExerciseCount(for group: MuscleCategoryGroup) -> (total: Int, active: Int)? {
        exerciseCounts[group]
    }

    func hasInactiveExercises() -> Bool {
        return exerciseManagementService.hasInactiveExercises(for: MuscleCategoryGroup.allCases)
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
    
    // MARK: - Exercise Access
    
    func getExercises(for category: MuscleCategoryGroup) -> [Exercise] {
        return exerciseManagementService.getExercises(for: category)
    }
    
    func updateExercise(_ updatedExercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.updateExercise(updatedExercise, category: category)
        // Trigger UI update by updating exercise counts
        updateExerciseCounts()
    }
    
    func completeExercise(_ exercise: Exercise, category: MuscleCategoryGroup, setProgress: [SetProgress]) {
        exerciseManagementService.completeExercise(exercise, category: category, setProgress: setProgress)
        updateExerciseCounts()
    }
    
    func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.resetExercise(exercise, category: category)
        updateExerciseCounts()
    }
    
    // MARK: - Exercise Finding
    
    func findCategoryForExercise(_ exercise: Exercise) -> MuscleCategoryGroup? {
        for category in MuscleCategoryGroup.allCases {
            let exercises = getExercises(for: category)
            if exercises.contains(where: { $0.id == exercise.id }) {
                return category
            }
        }
        return nil
    }
    
    func allExercises() -> [Exercise] {
        var allExercises: [Exercise] = []
        for category in MuscleCategoryGroup.allCases {
            allExercises.append(contentsOf: getExercises(for: category))
        }
        return allExercises
    }
    
    // MARK: - Workout Selection
    
    func selectWorkout(_ workout: Workout) {
        workoutStorageService.setCurrentWorkout(workout)
    }
}
