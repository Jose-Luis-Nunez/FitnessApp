import Foundation
import Observation
import FitnessCore
import FitnessStorage
import FitnessTraining
import Factory

@Observable
@MainActor
public final class MuscleCategoryViewModel {
    public var exercises: [Exercise]
    public var showResetConfirmation: Bool = false

    public let group: MuscleCategoryGroup
    public let formViewModel: ExerciseFormViewModel
    public let activeSetViewModel: ActiveSetViewModel
    private let storageService: ExerciseStoring
    private let workoutStorageService: WorkoutStoring
    private var cardViewModels: [UUID: ExerciseCardViewModel] = [:]
    nonisolated(unsafe) private var coordinatorObservationTask: Task<Void, Never>?

    public init(group: MuscleCategoryGroup) {
        self.group = group
        let ws = Container.shared.workoutStorage()
        self.workoutStorageService = ws
        self.formViewModel = ExerciseFormViewModel()
        let es = Container.shared.exerciseStorage()
        self.storageService = es

        if let currentWorkout = ws.currentWorkout {
            self.exercises = es.loadForWorkout(workoutId: currentWorkout.id, category: group)
        } else {
            self.exercises = []
        }
        self.activeSetViewModel = Container.shared.sessionTrainingCache().viewModel(for: group)

        let coordinator = Container.shared.trainingCoordinatorCache().coordinator(for: group)
        startCoordinatorObservation(coordinator)
    }

    public init(
        group: MuscleCategoryGroup,
        exercises: [Exercise],
        storageService: ExerciseStoring,
        workoutStorageService: WorkoutStoring,
        activeSetViewModel: ActiveSetViewModel,
        coordinator: TrainingCoordinator? = nil
    ) {
        self.group = group
        self.exercises = exercises
        self.storageService = storageService
        self.workoutStorageService = workoutStorageService
        self.formViewModel = ExerciseFormViewModel()
        self.activeSetViewModel = activeSetViewModel
        if let coordinator { startCoordinatorObservation(coordinator) }
    }

    deinit {
        coordinatorObservationTask?.cancel()
    }

    /// Observes `lastCompletedExercise` on the coordinator. When an exercise is
    /// completed, updates the local `exercises` array in-place — no DB roundtrip.
    private func startCoordinatorObservation(_ coordinator: TrainingCoordinator) {
        coordinatorObservationTask = Task { [weak self] in
            while !Task.isCancelled {
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = coordinator.lastCompletedExercise
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard let self, !Task.isCancelled else { return }
                if let completed = coordinator.lastCompletedExercise,
                   let index = self.exercises.firstIndex(where: { $0.id == completed.id }) {
                    self.exercises[index] = completed
                }
            }
        }
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
        guard let currentWorkout = workoutStorageService.currentWorkout else { return }
        storageService.saveForWorkout(exercises, workoutId: currentWorkout.id, category: group)
    }

    public func refreshExercises() {
        guard let currentWorkout = workoutStorageService.currentWorkout else {
            exercises = []
            return
        }
        exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: group)
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
