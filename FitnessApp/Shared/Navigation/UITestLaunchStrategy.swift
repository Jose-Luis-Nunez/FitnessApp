#if UITESTING
import UIKit
import FitnessCore
import FitnessStorage
import FitnessExercise

struct UITestLaunchStrategy: AppLaunchStrategy {
    let config: UITestLaunchConfig

    func prepare(workoutService: WorkoutStorageService) {
        workoutService.setCurrentWorkout(Workout(name: "Test Workout"))
    }

    func initialNavigationStack(workoutService: WorkoutStorageService) -> [NavigationDestination] {
        switch config.screen {
        case .training:
            guard let name = config.exerciseName,
                  let weight = config.weight,
                  let reps = config.reps,
                  let sets = config.sets,
                  let category = MuscleCategoryGroup(rawValue: config.category)
            else { return [] }

            let exercise = Exercise(
                name: name, weight: weight, reps: reps, sets: sets,
                noSeats: config.noSeats ?? true,
                iconName: config.icon ?? "dumbbell",
                category: category
            )
            return [.home, .muscleCategory(category), .training(exercise, category)]

        case .category:
            guard let category = MuscleCategoryGroup(rawValue: config.category)
            else { return [] }
            return [.home, .muscleCategory(category)]

        case .schedule:
            return [.schedule]
        }
    }

    func configureEnvironment() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.layer.speed = 100 }
    }
}
#endif
