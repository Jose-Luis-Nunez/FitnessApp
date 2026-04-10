import Foundation
import FitnessCore
import FitnessStorage
import FitnessTraining

public class MuscleCategoryViewModel: ObservableObject {
    @Published public var exercises: [Exercise]
    @Published public var showResetConfirmation: Bool = false

    public let group: MuscleCategoryGroup
    public let formViewModel: ExerciseFormViewModel
    public let activeSetViewModel: ActiveSetViewModel
    private let storageService: ExerciseStoring
    private let workoutStorageService: WorkoutStorageService
    private var cardViewModels: [UUID: ExerciseCardViewModel] = [:]

    public init(group: MuscleCategoryGroup, workoutStorageService: WorkoutStorageService = .shared) {
        self.group = group
        self.workoutStorageService = workoutStorageService
        self.formViewModel = ExerciseFormViewModel()
        self.storageService = ExerciseStorageService()

        if let currentWorkout = workoutStorageService.currentWorkout {
            self.exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: group)
        } else {
            self.exercises = storageService.load(for: group)
        }
        self.activeSetViewModel = SessionTrainingCache.shared.viewModel(for: group)
    }

    public init(
        group: MuscleCategoryGroup,
        exercises: [Exercise],
        storageService: ExerciseStoring,
        workoutStorageService: WorkoutStorageService,
        activeSetViewModel: ActiveSetViewModel
    ) {
        self.group = group
        self.exercises = exercises
        self.storageService = storageService
        self.workoutStorageService = workoutStorageService
        self.formViewModel = ExerciseFormViewModel()
        self.activeSetViewModel = activeSetViewModel
    }

    public var hasActiveExercise: Bool {
        exercises.contains { !$0.isCompleted }
    }

    public var isTrainingInProgress: Bool {
        activeSetViewModel.currentExercise != nil || activeSetViewModel.isSetInProgress
    }

    public var hasCompletedExercises: Bool {
        exercises.contains { $0.isCompleted }
    }

    public var showCancel: Bool { isTrainingInProgress }
    public var showNewExercise: Bool { !isTrainingInProgress }
    public var showStartTraining: Bool { !isTrainingInProgress && hasActiveExercise }
    public var showReset: Bool { !isTrainingInProgress && hasCompletedExercises }

    public var totalExercises: Int {
        exercises.count
    }

    public var activeExercises: Int {
        exercises.filter { !$0.isCompleted }.count
    }

    public func add(_ exercise: Exercise, atTop: Bool) {
        if atTop {
            exercises.insert(exercise, at: 0)
        } else {
            exercises.append(exercise)
        }
        saveExercises()
    }

    public func updateExercise(_ updatedExercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            exercises[index] = updatedExercise
            if activeSetViewModel.currentExercise?.id == updatedExercise.id {
                activeSetViewModel.currentExercise = updatedExercise
            }
            saveExercises()
        }
    }

    public func resetProgress() {
        exercises = exercises.map { exercise in
            var updated = exercise
            updated.isCompleted = false
            return updated
        }
        activeSetViewModel.resetProgress()
        activeSetViewModel.stopTimer()
        saveExercises()
    }

    public func saveExercises() {
        if let currentWorkout = workoutStorageService.currentWorkout {
            storageService.saveForWorkout(exercises, workoutId: currentWorkout.id, category: group)
        } else {
            storageService.save(exercises, for: group)
        }
    }

    public func refreshExercises() {
        if let currentWorkout = workoutStorageService.currentWorkout {
            exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: group)
        } else {
            exercises = storageService.load(for: group)
        }
    }

    public func resetExercise(_ exercise: Exercise) {
        var updatedExercise = exercise
        updatedExercise.isCompleted = false
        updatedExercise.sets = exercise.sets
        updatedExercise.reps = exercise.reps
        updatedExercise.weight = exercise.weight
        updateExercise(updatedExercise)
    }

    public func cardViewModel(for exercise: Exercise) -> ExerciseCardViewModel {
        if let existing = cardViewModels[exercise.id] {
            existing.syncExercise(exercise)
            return existing
        }
        let vm = ExerciseCardViewModel(exercise: exercise) { [weak self] updated in
            self?.updateExercise(updated)
        }
        cardViewModels[exercise.id] = vm
        return vm
    }

    public func invalidateCardViewModels() {
        cardViewModels.removeAll()
    }
}
