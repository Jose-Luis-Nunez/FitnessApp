import Foundation
import FitnessCore
import FitnessStorage
import FitnessExercise

@MainActor
protocol AppLaunchStrategy {
    func prepare(workoutService: WorkoutStorageService)
    func initialNavigationStack(workoutService: WorkoutStorageService) -> [NavigationDestination]
    func configureEnvironment()
}

struct ProductionLaunchStrategy: AppLaunchStrategy {
    func prepare(workoutService: WorkoutStorageService) {
        if let defaultWorkout = workoutService.defaultWorkout {
            workoutService.setCurrentWorkout(defaultWorkout)
        }
    }

    func initialNavigationStack(workoutService: WorkoutStorageService) -> [NavigationDestination] {
        workoutService.defaultWorkout != nil ? [.home] : []
    }

    func configureEnvironment() {}
}
