import Foundation
import FitnessCore
import Factory

@MainActor
public struct DuplicateWorkoutUseCase {
    private let workoutStorageService: WorkoutStoring

    public init(workoutStorage: WorkoutStoring? = nil) {
        self.workoutStorageService = workoutStorage ?? Container.shared.workoutStorage()
    }

    /// Creates a copy of the workout including all exercises per category.
    public func execute(_ workout: Workout) -> Workout {
        workoutStorageService.duplicateWorkout(workout)
    }
}
