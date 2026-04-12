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
    public var exercisesByCategory: [MuscleCategoryGroup: [Exercise]] = [:]

    @ObservationIgnored @Injected(\.exerciseManagement) private var exerciseManagementService
    @ObservationIgnored @Injected(\.workoutStorage) private var workoutStorageService

    private var exerciseCounts: [MuscleCategoryGroup: (total: Int, active: Int)] {
        exercisesByCategory.mapValues { exercises in
            (total: exercises.count, active: exercises.filter { !$0.isCompleted }.count)
        }
    }

    private var cardViewModels: [UUID: ExerciseCardViewModel] = [:]
    nonisolated(unsafe) private var workoutObservationTask: Task<Void, Never>?
    nonisolated(unsafe) private var coordinatorObservationTasks: [Task<Void, Never>] = []

    @ObservationIgnored private let coordinatorCache: TrainingCoordinatorCaching

    public init(coordinatorCache: TrainingCoordinatorCaching? = nil) {
        self.coordinatorCache = coordinatorCache ?? Container.shared.trainingCoordinatorCache()
        updateCategories(for: workoutStorageService.currentWorkout)
        refreshExercises()
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
                self.refreshExercises()
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
                if let completed = coordinator.lastCompletedExercise {
                    for (category, exercises) in self.exercisesByCategory {
                        if let index = exercises.firstIndex(where: { $0.id == completed.id }) {
                            var patched = exercises
                            patched[index] = completed
                            self.exercisesByCategory[category] = patched
                            break
                        }
                    }
                    self.cardViewModels[completed.id]?.syncExercise(completed)
                }
            }
        }
        coordinatorObservationTasks.append(task)
    }

    @ObservationIgnored @Injected(\.resetAllExercisesUseCase) private var resetAllExercisesUseCase

    public func resetAllExercises() {
        guard workoutStorageService.currentWorkout != nil else { return }
        resetAllExercisesUseCase.execute(for: MuscleCategoryGroup.allCases)
        refreshExercises()
    }

    public func refreshExercises() {
        var updated: [MuscleCategoryGroup: [Exercise]] = [:]
        for category in categories {
            updated[category] = exerciseManagementService.getExercises(for: category)
        }
        exercisesByCategory = updated
    }

    public func getExerciseCount(for group: MuscleCategoryGroup) -> (total: Int, active: Int)? {
        exerciseCounts[group]
    }

    public func hasInactiveExercises() -> Bool {
        exerciseManagementService.hasInactiveExercises(for: MuscleCategoryGroup.allCases)
    }

    public func hasActiveSetForCategory(_ group: MuscleCategoryGroup) -> Bool {
        coordinatorCache.coordinator(for: group).hasActiveSessions
    }

    private func updateCategories(for workout: Workout?) {
        if let workout = workout {
            categories = Array(workout.selectedCategories).sorted { $0.rawValue < $1.rawValue }
        } else {
            categories = []
        }
    }

    public func getExercises(for category: MuscleCategoryGroup) -> [Exercise] {
        exercisesByCategory[category] ?? []
    }

    public func updateExercise(_ updatedExercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.updateExercise(updatedExercise, category: category)
        if var exercises = exercisesByCategory[category],
           let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            exercises[index] = updatedExercise
            exercisesByCategory[category] = exercises
        }
    }

    public func addExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.addExercise(exercise, category: category, atTop: true)
        var exercises = exercisesByCategory[category] ?? []
        exercises.insert(exercise, at: 0)
        exercisesByCategory[category] = exercises
    }

    public func completeExercise(_ exercise: Exercise, category: MuscleCategoryGroup, setProgress: [SetProgress]) {
        exerciseManagementService.completeExercise(exercise, category: category, setProgress: setProgress)
        if var exercises = exercisesByCategory[category],
           let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            var updated = exercise
            updated.isCompleted = true
            exercises[index] = updated
            exercisesByCategory[category] = exercises
        }
    }

    public func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.resetExercise(exercise, category: category)
        if var exercises = exercisesByCategory[category],
           let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            var updated = exercise
            updated.isCompleted = false
            exercises[index] = updated
            exercisesByCategory[category] = exercises
        }
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
