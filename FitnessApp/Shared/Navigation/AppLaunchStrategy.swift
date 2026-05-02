import Foundation
import FitnessCore
import FitnessExercise

@MainActor
protocol AppLaunchStrategy {
    func prepare(workoutService: WorkoutStoring)
    func initialNavigationStack(workoutService: WorkoutStoring) -> [NavigationDestination]
    func configureEnvironment()
}

struct ProductionLaunchStrategy: AppLaunchStrategy {
    func prepare(workoutService: WorkoutStoring) {
        if let defaultWorkout = workoutService.defaultWorkout {
            workoutService.setCurrentWorkout(defaultWorkout)
        }
    }

    func initialNavigationStack(workoutService: WorkoutStoring) -> [NavigationDestination] {
        workoutService.defaultWorkout != nil ? [.home] : []
    }

    func configureEnvironment() {}
}
