import Foundation
import FitnessCore
import Factory

@MainActor
public struct DeleteWorkoutUseCase {
    @Injected(\.workoutStorage) private var workoutStorageService
    @Injected(\.exerciseStorage) private var exerciseStorageService

    public init() {}

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
