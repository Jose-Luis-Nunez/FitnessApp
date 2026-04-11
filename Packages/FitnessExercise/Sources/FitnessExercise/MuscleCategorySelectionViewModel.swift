import Foundation
import Observation
import FitnessCore
import FitnessStorage
import FitnessTraining
import Factory

@Observable
@MainActor
public final class MuscleCategorySelectionViewModel {
    public var categories: [MuscleCategoryGroup] = []

    @ObservationIgnored @Injected(\.exerciseManagement) private var exerciseManagementService
    @ObservationIgnored @Injected(\.workoutStorage) private var workoutStorageService

    private var exerciseCounts: [MuscleCategoryGroup: (total: Int, active: Int)] = [:]
    private var cardViewModels: [UUID: ExerciseCardViewModel] = [:]
    nonisolated(unsafe) private var workoutObservationTask: Task<Void, Never>?
    nonisolated(unsafe) private var coordinatorObservationTasks: [Task<Void, Never>] = []

    @ObservationIgnored private let coordinatorCache: TrainingCoordinatorCaching

    public init(coordinatorCache: TrainingCoordinatorCaching? = nil) {
        self.coordinatorCache = coordinatorCache ?? Container.shared.trainingCoordinatorCache()
        updateExerciseCounts()
        updateCategories(for: workoutStorageService.currentWorkout)
        startWorkoutObservation()
        restartCoordinatorObservations()
    }

    deinit {
        workoutObservationTask?.cancel()
        coordinatorObservationTasks.forEach { $0.cancel() }
    }

    private func startWorkoutObservation() {
        workoutObservationTask?.cancel()
        let ws = workoutStorageService
        workoutObservationTask = Task { [weak self] in
            while !Task.isCancelled {
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = ws.currentWorkout
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard let self, !Task.isCancelled else { return }
                self.updateCategories(for: ws.currentWorkout)
                self.updateExerciseCounts()
                self.restartCoordinatorObservations()
            }
        }
    }

    private func restartCoordinatorObservations() {
        coordinatorObservationTasks.forEach { $0.cancel() }
        coordinatorObservationTasks.removeAll()
        for group in categories {
            let coordinator = coordinatorCache.coordinator(for: group)
            startCoordinatorObservation(coordinator)
        }
    }

    private func startCoordinatorObservation(_ coordinator: TrainingCoordinator) {
        let task = Task { [weak self] in
            while !Task.isCancelled {
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = coordinator.lastCompletedExercise
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard let self, !Task.isCancelled else { return }
                if coordinator.lastCompletedExercise != nil {
                    self.updateExerciseCounts()
                }
            }
        }
        coordinatorObservationTasks.append(task)
    }

    @ObservationIgnored @Injected(\.sessionTrainingCache) private var sessionTrainingCache
    @ObservationIgnored @Injected(\.resetAllExercisesUseCase) private var resetAllExercisesUseCase

    public func resetAllExercises() {
        guard workoutStorageService.currentWorkout != nil else { return }
        resetAllExercisesUseCase.execute(for: MuscleCategoryGroup.allCases)
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
        sessionTrainingCache.activeSetVMs[group]?.currentExercise != nil
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
