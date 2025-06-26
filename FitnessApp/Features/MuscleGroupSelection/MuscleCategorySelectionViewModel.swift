import Foundation

class MuscleCategorySelectionViewModel: ObservableObject {
    @Published var categories: [MuscleCategoryGroup] = MuscleCategoryGroup.allCases
    @Published var bottomBarViewModel: BottomActionBarViewModel

    private let storageService = ExerciseStorageService()

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
    }

    func resetAllExercises() {
        for (_, activeSetVM) in SessionTrainingCache.shared.activeSetVMs {
            activeSetVM.cancelActiveSet()
        }

        for group in MuscleCategoryGroup.allCases {
            let exercises = storageService.load(for: group)
            let updatedExercises = exercises.map { exercise in
                var updatedExercise = exercise
                updatedExercise.isCompleted = false
                return updatedExercise
            }
            storageService.save(updatedExercises, for: group)
        }
        updateExerciseCountsAndViewModel()
    }

    func updateExerciseCounts() {
        for group in MuscleCategoryGroup.allCases {
            let exercises = storageService.load(for: group)
            exerciseCounts[group] = (total: exercises.count, active: exercises.filter { !$0.isCompleted }.count)
        }
    }
    
    func getExerciseCount(for group: MuscleCategoryGroup) -> (total: Int, active: Int)? {
        exerciseCounts[group]
    }

    private func hasInactiveExercises() -> Bool {
        for group in MuscleCategoryGroup.allCases {
            let exercises = storageService.load(for: group)
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
}
