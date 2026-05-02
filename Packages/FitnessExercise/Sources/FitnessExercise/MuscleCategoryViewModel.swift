import Foundation
import Observation
import FitnessCore
import FitnessStorage
import FitnessTraining
import Factory

@Observable
@MainActor
public final class MuscleCategoryViewModel {
    public private(set) var exercises: [Exercise]
    public var showResetConfirmation: Bool = false

    public let group: MuscleCategoryGroup
    public let formViewModel: ExerciseFormViewModel
    public let activeSetViewModel: ActiveSetViewModel
    private let coordinator: TrainingCoordinator
    private let storageService: ExerciseStoring
    private let workoutStorageService: WorkoutStoring

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

        let coord = Container.shared.trainingCoordinatorCache().coordinator(for: group)
        self.coordinator = coord
        self.activeSetViewModel = coord.activeSetViewModel
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
        self.coordinator = coordinator ?? TrainingCoordinator(
            findCategory: { _ in group },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in }
        )
    }

    public var hasActiveExercise: Bool {
        exercises.contains { !$0.isCompleted }
    }

    public var isTrainingInProgress: Bool {
        coordinator.hasActiveSessions
    }

    public var hasCompletedExercises: Bool {
        exercises.contains { $0.isCompleted }
    }

    /// Exposes the persisted ID of the currently selected workout so that
    /// SwiftData-backed views (e.g. `ExerciseCardModelView` from
    /// `FitnessPersistenceUI`) can build a `@Query` predicate filtered by
    /// `workoutId`. Returns `nil` while no workout is selected; callers must
    /// handle that case (no card is rendered then anyway).
    public var currentWorkoutId: UUID? {
        workoutStorageService.currentWorkout?.id
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
            if let vm = coordinator.session(for: updatedExercise.id) {
                vm.currentExercise = updatedExercise
            }
            saveExercises()
        }
    }

    public func resetProgress() {
        let activeIds = Array(coordinator.activeSessions.keys)
        for id in activeIds {
            coordinator.cancelTraining(for: id)
        }
        exercises = exercises.map { exercise in
            var updated = exercise
            updated.isCompleted = false
            return updated
        }
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

    public func deleteExercise(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises.remove(at: index)
            saveExercises()
        }
    }

    public func resetExercise(_ exercise: Exercise) {
        var updatedExercise = exercise
        updatedExercise.isCompleted = false
        updateExercise(updatedExercise)
    }
}
