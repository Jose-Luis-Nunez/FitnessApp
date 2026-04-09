#if UITESTING
import SwiftUI
import UIKit

enum UITestRouter {
    static func configure(
        config: UITestLaunchConfig,
        navigationPath: inout NavigationPath,
        workoutStorageService: WorkoutStorageService
    ) {
        workoutStorageService.setCurrentWorkout(Workout(name: "Test Workout"))

        switch config.screen {
        case .training:
            guard let name = config.exerciseName,
                  let weight = config.weight,
                  let reps = config.reps,
                  let sets = config.sets,
                  let category = MuscleCategoryGroup(rawValue: config.category)
            else { return }

            let exercise = Exercise(
                name: name, weight: weight, reps: reps, sets: sets,
                noSeats: config.noSeats ?? true,
                iconName: config.icon ?? "dumbbell",
                category: category
            )
            navigationPath.append(NavigationDestination.home)
            navigationPath.append(NavigationDestination.muscleCategory(category))
            navigationPath.append(NavigationDestination.training(exercise, category))

        case .category:
            guard let category = MuscleCategoryGroup(rawValue: config.category)
            else { return }
            navigationPath.append(NavigationDestination.home)
            navigationPath.append(NavigationDestination.muscleCategory(category))

        case .schedule:
            navigationPath.append(NavigationDestination.schedule)
        }
    }

    static func speedUpAnimations() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.layer.speed = 100 }
    }
}
#endif // UITESTING
