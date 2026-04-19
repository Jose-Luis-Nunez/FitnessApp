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

    nonisolated(unsafe) private var workoutObservationTask: Task<Void, Never>?

    @ObservationIgnored private let coordinatorCache: TrainingCoordinatorCaching

    public init(
        coordinatorCache: TrainingCoordinatorCaching? = nil,
        exerciseManagement: ExerciseManaging? = nil,
        workoutStorage: WorkoutStoring? = nil
    ) {
        self.coordinatorCache = coordinatorCache ?? Container.shared.trainingCoordinatorCache()
        self.exerciseManagementService = exerciseManagement ?? Container.shared.exerciseManagement()
        self.workoutStorageService = workoutStorage ?? Container.shared.workoutStorage()
        updateCategories(for: workoutStorageService.currentWorkout)
        refreshExercises()
        startWorkoutObservation()
    }

    deinit {
        workoutObservationTask?.cancel()
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

    /// Exposes the persisted ID of the currently selected workout so that
    /// SwiftData-backed views (e.g. `CategoryTileModelView` from
    /// `FitnessPersistenceUI`) can build a `@Query` predicate filtered by
    /// `workoutId`. Returns `nil` while no workout is selected; callers must
    /// handle that case (no tile is rendered then anyway because `categories`
    /// is empty).
    public var currentWorkoutId: UUID? {
        workoutStorageService.currentWorkout?.id
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
}
