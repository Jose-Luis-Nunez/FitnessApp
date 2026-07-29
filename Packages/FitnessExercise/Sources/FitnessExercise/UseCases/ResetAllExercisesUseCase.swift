import Foundation
import FitnessCore
import FitnessStorage
import FitnessTraining
import Factory

@MainActor
public struct ResetAllExercisesUseCase {
    private let coordinatorCache: TrainingCoordinatorCaching
    private let exerciseManagementService: ExerciseManaging
    private let workoutStorageService: WorkoutStoring
    private let exerciseOrderStorage: WorkoutExerciseOrderStoring

    public init(
        coordinatorCache: TrainingCoordinatorCaching? = nil,
        exerciseManagement: ExerciseManaging? = nil,
        workoutStorage: WorkoutStoring? = nil,
        exerciseOrderStorage: WorkoutExerciseOrderStoring? = nil
    ) {
        self.coordinatorCache = coordinatorCache ?? Container.shared.trainingCoordinatorCache()
        self.exerciseManagementService = exerciseManagement ?? Container.shared.exerciseManagement()
        self.workoutStorageService = workoutStorage ?? Container.shared.workoutStorage()
        self.exerciseOrderStorage = exerciseOrderStorage ?? Container.shared.workoutExerciseOrderStorage()
    }

    /// Finalizes the workout-wide observed exercise order, cancels all active
    /// training sessions across every category, then resets the persisted
    /// exercise state. Uses the coordinator's own
    /// `cancelTraining(for:)` so that both the VM **and** the coordinator's
    /// internal bookkeeping (`activeSessions`, `activeExercises`,
    /// `focusedExerciseId`) are cleaned up consistently.
    public func execute(for categories: [MuscleCategoryGroup]) {
        if let workoutId = workoutStorageService.currentWorkout?.id {
            exerciseOrderStorage.finalizeCycle(workoutId: workoutId)
        }

        for category in categories {
            let coordinator = coordinatorCache.coordinator(for: category)
            for exerciseId in Array(coordinator.activeSessions.keys) {
                coordinator.cancelTraining(for: exerciseId)
            }
        }

        exerciseManagementService.resetAllExercises(for: categories)
    }
}
