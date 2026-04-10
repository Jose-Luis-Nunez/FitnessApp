import Foundation
import Combine
import FitnessCore
import FitnessStorage
import FitnessTraining

public class MuscleCategorySelectionViewModel: ObservableObject {
    @Published public var categories: [MuscleCategoryGroup] = []

    private let exerciseManagementService: ExerciseManagementService
    private let workoutStorageService: WorkoutStorageService
    private var cancellables = Set<AnyCancellable>()

    @Published private var exerciseCounts: [MuscleCategoryGroup: (total: Int, active: Int)] = [:]
    private var cardViewModels: [UUID: ExerciseCardViewModel] = [:]

    public init(
        workoutStorageService: WorkoutStorageService = .shared,
        exerciseManagementService: ExerciseManagementService = ExerciseManagementService()
    ) {
        self.workoutStorageService = workoutStorageService
        self.exerciseManagementService = exerciseManagementService
        updateExerciseCounts()

        workoutStorageService.$currentWorkout
            .sink { [weak self] currentWorkout in
                self?.updateCategories(for: currentWorkout)
                self?.updateExerciseCounts()
            }
            .store(in: &cancellables)

        updateCategories(for: workoutStorageService.currentWorkout)
    }

    public func resetAllExercises() {
        guard workoutStorageService.currentWorkout != nil else { return }

        for (_, activeSetVM) in SessionTrainingCache.shared.activeSetVMs {
            activeSetVM.cancelActiveSet()
        }

        exerciseManagementService.resetAllExercises(for: MuscleCategoryGroup.allCases)
        updateExerciseCounts()
    }

    public func updateExerciseCounts() {
        exerciseCounts = exerciseManagementService.getAllExerciseCounts(for: MuscleCategoryGroup.allCases)
    }

    public func getExerciseCount(for group: MuscleCategoryGroup) -> (total: Int, active: Int)? {
        exerciseCounts[group]
    }

    public func hasInactiveExercises() -> Bool {
        exerciseManagementService.hasInactiveExercises(for: MuscleCategoryGroup.allCases)
    }

    public func hasActiveSetForCategory(_ group: MuscleCategoryGroup) -> Bool {
        SessionTrainingCache.shared.activeSetVMs[group]?.currentExercise != nil
    }

    private func updateCategories(for workout: Workout?) {
        if let workout = workout {
            categories = Array(workout.selectedCategories).sorted { $0.rawValue < $1.rawValue }
        } else {
            categories = []
        }
    }

    public func getExercises(for category: MuscleCategoryGroup) -> [Exercise] {
        exerciseManagementService.getExercises(for: category)
    }

    public func updateExercise(_ updatedExercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.updateExercise(updatedExercise, category: category)
        updateExerciseCounts()
    }

    public func addExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.addExercise(exercise, category: category, atTop: true)
        updateExerciseCounts()
    }

    public func completeExercise(_ exercise: Exercise, category: MuscleCategoryGroup, setProgress: [SetProgress]) {
        exerciseManagementService.completeExercise(exercise, category: category, setProgress: setProgress)
        updateExerciseCounts()
    }

    public func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.resetExercise(exercise, category: category)
        updateExerciseCounts()
    }

    public func findCategoryForExercise(_ exercise: Exercise) -> MuscleCategoryGroup? {
        for category in MuscleCategoryGroup.allCases {
            let exercises = getExercises(for: category)
            if exercises.contains(where: { $0.id == exercise.id }) {
                return category
            }
        }
        return nil
    }

    public func allExercises() -> [Exercise] {
        var allExercises: [Exercise] = []
        for category in MuscleCategoryGroup.allCases {
            allExercises.append(contentsOf: getExercises(for: category))
        }
        return allExercises
    }

    public func selectWorkout(_ workout: Workout) {
        workoutStorageService.setCurrentWorkout(workout)
    }

    public func cardViewModel(for exercise: Exercise, category: MuscleCategoryGroup) -> ExerciseCardViewModel {
        if let existing = cardViewModels[exercise.id] {
            existing.syncExercise(exercise)
            return existing
        }
        let vm = ExerciseCardViewModel(exercise: exercise) { [weak self] updated in
            self?.updateExercise(updated, category: category)
        }
        cardViewModels[exercise.id] = vm
        return vm
    }
}
