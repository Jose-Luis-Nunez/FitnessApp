import Foundation
import FitnessCore
import Factory

@MainActor
public struct DuplicateWorkoutUseCase {
    @Injected(\.workoutStorage) private var workoutStorageService

    public init() {}

    /// Creates a copy of the workout including all exercises per category.
    public func execute(_ workout: Workout) -> Workout {
        workoutStorageService.duplicateWorkout(workout)
    }
}
