#if UITESTING
import UIKit
import FitnessCore
import FitnessExercise
import Factory
import SwiftData
@_spi(PersistenceUI) import FitnessStorage

struct UITestLaunchStrategy: AppLaunchStrategy {
    let config: UITestLaunchConfig

    /// Stable id for the seeded training fixture, derived once at init time
    /// and re-used by both `prepare(...)` and `initialNavigationStack(...)`.
    /// Per-instance (not static) so parallel UI-test runners cannot stomp
    /// each other's seed — `parallelizable = "YES"` on the UITests scheme.
    /// Post-T8d, `TrainingView` resolves this id to a live `ExerciseModel`
    /// via `@Query`, so the navigation arg and the persisted record must
    /// agree, and both phases of the launch pipeline must see the same id.
    let seededTrainingExerciseId: UUID?

    init(config: UITestLaunchConfig) {
        self.config = config
        self.seededTrainingExerciseId = config.screen == .training ? UUID() : nil
    }

    func prepare(workoutService: WorkoutStoring) {
        let workout = Workout(name: "Test Workout")
        workoutService.setCurrentWorkout(workout)

        // For the training launch, seed BOTH the workout and the fixture
        // exercise directly into the SwiftData container. Pre-T8d the legacy
        // `TrainingView` accepted the in-memory `Exercise` literal and never
        // touched the store; post-T8d it resolves an `ExerciseModel` via
        // `@Query` so we must materialise a live record.
        //
        // We seed via a fresh `ModelContext` against the same container the
        // app reads from (Factory singleton). Going through
        // `ExerciseManagementService.addExercise(...)` doesn't work here
        // because `setCurrentWorkout(_:)` only flips an in-memory flag — the
        // `WorkoutModel` row is never persisted, so the management service
        // saves the exercise with `workoutId == nil` and most production
        // queries won't see it.
        guard config.screen == .training,
              let id = seededTrainingExerciseId,
              let exercise = makeFixtureExercise(id: id) else { return }
        seedFixture(workout: workout, exercise: exercise)
    }

    func initialNavigationStack(workoutService: WorkoutStoring) -> [NavigationDestination] {
        switch config.screen {
        case .training:
            guard let category = MuscleCategoryGroup(rawValue: config.category),
                  let exerciseId = seededTrainingExerciseId
            else { return [] }
            return [.home, .muscleCategory(category), .training(exerciseId: exerciseId, category: category)]

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

    private func makeFixtureExercise(id: UUID) -> Exercise? {
        guard let name = config.exerciseName,
              let weight = config.weight,
              let reps = config.reps,
              let sets = config.sets,
              let category = MuscleCategoryGroup(rawValue: config.category)
        else { return nil }

        return Exercise(
            id: id,
            name: name, weight: weight, reps: reps, sets: sets,
            noSeats: config.noSeats ?? true,
            iconName: config.icon ?? "dumbbell",
            category: category
        )
    }

    @MainActor
    private func seedFixture(workout: Workout, exercise: Exercise) {
        let container = Container.shared.modelContainer()
        let context = ModelContext(container)

        let workoutModel = WorkoutModel(
            id: workout.id,
            name: workout.name,
            selectedCategories: workout.selectedCategories.map(\.rawValue),
            createdDate: workout.createdDate,
            lastModified: workout.lastModified,
            isDefault: false
        )
        context.insert(workoutModel)

        let exerciseModel = ExerciseModel(
            id: exercise.id,
            workoutId: workout.id,
            name: exercise.name,
            weight: exercise.weight,
            reps: exercise.reps,
            sets: exercise.sets,
            seatSetting: exercise.seatSetting,
            noSeats: exercise.noSeats,
            isCompleted: exercise.isCompleted,
            iconName: exercise.iconName,
            category: exercise.category.rawValue,
            goal: exercise.goal,
            sortOrder: 0,
            workout: workoutModel
        )
        context.insert(exerciseModel)

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to seed UI test fixture: \(error)")
        }
    }
}
#endif
