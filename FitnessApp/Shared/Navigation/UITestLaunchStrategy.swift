#if UITESTING
import UIKit
import FitnessCore
import FitnessExercise
import Factory
import SwiftData
@_spi(PersistenceUI) import FitnessStorage

struct UITestLaunchStrategy: AppLaunchStrategy {
    let config: UITestLaunchConfig

    /// Stable id for the seeded exercise fixture, derived once at init time
    /// and re-used by both `prepare(...)` and `initialNavigationStack(...)`.
    /// Per-instance (not static) so parallel UI-test runners cannot stomp
    /// each other's seed — `parallelizable = "YES"` on the UITests scheme.
    /// Post-T8d, `TrainingView` resolves this id to a live `ExerciseModel`
    /// via `@Query`, so the navigation arg and the persisted record must
    /// agree, and both phases of the launch pipeline must see the same id.
    let seededExerciseId: UUID?
    let seededAdditionalExerciseIds: [UUID]

    init(config: UITestLaunchConfig) {
        self.config = config
        seededExerciseId = config.exerciseName == nil ? nil : UUID()
        seededAdditionalExerciseIds = (config.additionalExercises ?? []).map { _ in UUID() }
    }

    func prepare(workoutService: WorkoutStoring) {
        if config.screen == .home {
            // UI tests must not inherit workouts from a prior test launch.
            // Reset only inside the UITESTING build, then seed two complete
            // rows so both column and row spacing are deterministic.
            for workout in workoutService.workouts {
                workoutService.deleteWorkout(workout)
            }

            // Navigation tests start at Home with a concrete exercise fixture.
            // Keep that distinct from the grid-geometry fixture below so the
            // test receives a single, deterministic workout and exercise.
            if let exercise = makePrimaryFixtureExercise() {
                let workout: Workout
                do {
                    workout = try workoutService.createWorkout(
                        name: "Test Workout",
                        selectedCategories: Set(MuscleCategoryGroup.allCases),
                        type: .full
                    )
                } catch {
                    preconditionFailure("Failed to seed workout UI fixture: \(error)")
                }
                workoutService.setCurrentWorkout(workout)
                seedFixture(
                    workout: workout,
                    exercises: [exercise] + makeAdditionalFixtureExercises()
                )
                return
            }

            let fixtures: [(name: String, type: WorkoutType)] = [
                ("Pull Fixture", .pull),
                ("Leg Fixture", .leg),
                ("Push Fixture", .push),
                ("Full Fixture", .full),
            ]
            let seeded: [Workout]
            do {
                seeded = try fixtures.map { fixture in
                    try workoutService.createWorkout(
                        name: fixture.name,
                        selectedCategories: Set(MuscleCategoryGroup.allCases),
                        type: fixture.type
                    )
                }
            } catch {
                preconditionFailure("Failed to seed deterministic workout UI fixtures: \(error)")
            }
            if let first = seeded.first {
                workoutService.setCurrentWorkout(first)
                workoutService.setAsDefaultWorkout(first)
            }
            return
        }

        let workout = Workout(name: "Test Workout")
        workoutService.setCurrentWorkout(workout)

        // Exercise-navigation fixtures seed BOTH the workout and the fixture
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
        guard let exercise = makePrimaryFixtureExercise() else { return }
        seedFixture(
            workout: workout,
            exercises: [exercise] + makeAdditionalFixtureExercises()
        )
    }

    func initialNavigationStack(workoutService: WorkoutStoring) -> [NavigationDestination] {
        switch config.screen {
        case .home:
            return [.home]

        case .training:
            guard let category = MuscleCategoryGroup(rawValue: config.category),
                  let exerciseId = seededExerciseId
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

    private func makePrimaryFixtureExercise() -> Exercise? {
        guard let id = seededExerciseId else { return nil }
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
            isCompleted: config.isCompleted ?? false,
            iconName: config.icon ?? "dumbbell",
            category: category,
            executionMode: ExerciseExecutionMode(
                rawValue: config.executionMode ?? ""
            ) ?? .standard
        )
    }

    private func makeAdditionalFixtureExercises() -> [Exercise] {
        zip(seededAdditionalExerciseIds, config.additionalExercises ?? []).compactMap {
            id, fixture in
            guard let category = MuscleCategoryGroup(rawValue: fixture.category) else {
                return nil
            }
            return Exercise(
                id: id,
                name: fixture.exerciseName,
                weight: fixture.weight,
                reps: fixture.reps,
                sets: fixture.sets,
                noSeats: fixture.noSeats,
                isCompleted: fixture.isCompleted,
                iconName: fixture.icon,
                category: category,
                executionMode: ExerciseExecutionMode(rawValue: fixture.executionMode) ?? .standard
            )
        }
    }

    @MainActor
    private func seedFixture(workout: Workout, exercises: [Exercise]) {
        let container = Container.shared.modelContainer()
        let context = ModelContext(container)
        let workoutId = workout.id
        let descriptor = FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.id == workoutId }
        )
        let workoutModel: WorkoutModel
        do {
            if let existing = try context.fetch(descriptor).first {
                workoutModel = existing
            } else {
                let model = WorkoutModel(
                    id: workout.id,
                    name: workout.name,
                    selectedCategories: workout.selectedCategories.map(\.rawValue),
                    createdDate: workout.createdDate,
                    lastModified: workout.lastModified,
                    isDefault: false
                )
                context.insert(model)
                workoutModel = model
            }
        } catch {
            preconditionFailure("Failed to resolve workout UI fixture: \(error)")
        }

        for (sortOrder, exercise) in exercises.enumerated() {
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
                sortOrder: sortOrder,
                executionModeRaw: exercise.executionMode.rawValue,
                workout: workoutModel
            )
            context.insert(exerciseModel)
        }

        do {
            try context.save()
            seedAnalyticsHistoryIfRequested(for: exercises.first)
        } catch {
            assertionFailure("Failed to seed UI test fixture: \(error)")
        }
    }

    @MainActor
    private func seedAnalyticsHistoryIfRequested(for exercise: Exercise?) {
        guard config.seedAnalyticsHistory == true,
              let exercise,
              let historicalDate = Calendar.current.date(
                byAdding: .day,
                value: -1,
                to: Date()
              ) else {
            return
        }

        let progress = exercise.trainingSteps.map { step in
            SetProgress(
                status: .completedDone,
                currentReps: exercise.reps,
                weight: exercise.weight,
                side: step.side,
                logicalSetIndex: step.logicalSetIndex
            )
        }
        Container.shared.analyticsStorage().save(
            [
                AnalyticsEntry(
                    exerciseId: exercise.id,
                    date: historicalDate,
                    setProgress: progress
                )
            ],
            for: exercise.id
        )
    }
}
#endif
