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

    @ObservationIgnored private var exerciseManagementService: ExerciseManaging
    @ObservationIgnored private var workoutStorageService: WorkoutStoring

    private var exerciseCounts: [MuscleCategoryGroup: (total: Int, active: Int)] {
        exercisesByCategory.mapValues { exercises in
            (total: exercises.count, active: exercises.filter { !$0.isCompleted }.count)
        }
    }

    private var cardViewModels: [UUID: ExerciseCardViewModel] = [:]
    nonisolated(unsafe) private var workoutObservationTask: Task<Void, Never>?
    nonisolated(unsafe) private var storageObservationTask: Task<Void, Never>?

    @ObservationIgnored private let coordinatorCache: TrainingCoordinatorCaching
    @ObservationIgnored private var exerciseStorageService: ExerciseStoring

    public init(
        coordinatorCache: TrainingCoordinatorCaching? = nil,
        exerciseManagement: ExerciseManaging? = nil,
        workoutStorage: WorkoutStoring? = nil,
        exerciseStorage: ExerciseStoring? = nil
    ) {
        self.coordinatorCache = coordinatorCache ?? Container.shared.trainingCoordinatorCache()
        self.exerciseManagementService = exerciseManagement ?? Container.shared.exerciseManagement()
        self.workoutStorageService = workoutStorage ?? Container.shared.workoutStorage()
        self.exerciseStorageService = exerciseStorage ?? Container.shared.exerciseStorage()
        updateCategories(for: workoutStorageService.currentWorkout)
        refreshExercises()
        startWorkoutObservation()
        startStorageObservation()
    }

    deinit {
        workoutObservationTask?.cancel()
        storageObservationTask?.cancel()
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
            }
        }
    }

    /// Observes `exerciseStorageService.changeVersion` — re-fetches from
    /// the single source of truth whenever any write occurs.
    private func startStorageObservation() {
        storageObservationTask?.cancel()
        storageObservationTask = Task { [weak self] in
            while !Task.isCancelled {
                let changed: Bool = await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self?.exerciseStorageService.changeVersion
                    } onChange: {
                        continuation.resume(returning: true)
                    }
                }
                guard changed, let self, !Task.isCancelled else { return }
                self.refreshExercises()
                for exercises in self.exercisesByCategory.values {
                    for exercise in exercises {
                        self.cardViewModels[exercise.id]?.syncExercise(exercise)
                    }
                }
            }
        }
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
        refreshExercises()
    }

    public func addExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.addExercise(exercise, category: category, atTop: true)
        refreshExercises()
    }

    public func completeExercise(_ exercise: Exercise, category: MuscleCategoryGroup, setProgress: [SetProgress]) {
        exerciseManagementService.completeExercise(exercise, category: category, setProgress: setProgress)
        refreshExercises()
    }

    public func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.resetExercise(exercise, category: category)
        refreshExercises()
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
