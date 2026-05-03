import Foundation
import FitnessCore
import Factory

@MainActor
public struct DeleteWorkoutUseCase {
    private let workoutStorageService: WorkoutStoring
    private let exerciseStorageService: ExerciseStoring

    public init(
        workoutStorage: WorkoutStoring? = nil,
        exerciseStorage: ExerciseStoring? = nil
    ) {
        self.workoutStorageService = workoutStorage ?? Container.shared.workoutStorage()
        self.exerciseStorageService = exerciseStorage ?? Container.shared.exerciseStorage()
    }

    /// Deletes the workout, handles current-workout fallback, and cleans up exercise files.
    public func execute(_ workout: Workout) {
        let categoriesToClean = workout.selectedCategories
        let workoutId = workout.id

        workoutStorageService.deleteWorkout(workout)

        for category in categoriesToClean {
            exerciseStorageService.saveForWorkout([], workoutId: workoutId, category: category)
        }
    }
}
