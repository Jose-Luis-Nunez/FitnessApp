import Foundation
import os
import SwiftData
import FitnessCore

private let logger = Logger(subsystem: "FitnessStorage", category: "DataMigrationService")

@MainActor
public enum DataMigrationService {
    private static let migrationKey = "swiftdata_migration_complete"
    private static let workoutsKey = "stored_workouts"
    private static let currentWorkoutKey = "current_workout_id"
    private static let defaultWorkoutKey = "default_workout_id"

    public static func migrateIfNeeded(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        documentsDir: URL? = nil
    ) {
        guard !defaults.bool(forKey: migrationKey) else { return }

        guard let docsDir = documentsDir ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let hasLegacyWorkouts = defaults.data(forKey: workoutsKey) != nil
        let hasLegacyFiles = legacyFilesExist(in: docsDir)

        guard hasLegacyWorkouts || hasLegacyFiles else {
            defaults.set(true, forKey: migrationKey)
            return
        }

        do {
            try performMigration(context: context, defaults: defaults, documentsDir: docsDir)
            defaults.set(true, forKey: migrationKey)
        } catch {
            logger.error("Migration failed, will retry on next launch: \(error)")
        }
    }

    private static func performMigration(context: ModelContext, defaults: UserDefaults, documentsDir: URL) throws {
        let userId = defaults.string(forKey: "userId") ?? ""

        let workouts = loadLegacyWorkouts(defaults: defaults)
        let currentWorkoutId = defaults.string(forKey: currentWorkoutKey)
            .flatMap(UUID.init(uuidString:))
        let defaultWorkoutId = defaults.string(forKey: defaultWorkoutKey)
            .flatMap(UUID.init(uuidString:))

        for workout in workouts {
            let isDefault = workout.id == defaultWorkoutId
            let workoutModel = WorkoutModel.from(workout, isDefault: isDefault)
            context.insert(workoutModel)

            for category in MuscleCategoryGroup.allCases {
                let exercises = loadLegacyExercises(
                    workoutId: workout.id,
                    category: category,
                    userId: userId,
                    documentsDir: documentsDir,
                    isFirstWorkout: workout.id == workouts.first?.id
                )

                for (index, exercise) in exercises.enumerated() {
                    let exerciseModel = ExerciseModel.from(exercise, sortOrder: index, workout: workoutModel)
                    context.insert(exerciseModel)

                    let analytics = loadLegacyAnalytics(
                        exerciseId: exercise.id,
                        userId: userId,
                        documentsDir: documentsDir
                    )

                    for entry in analytics {
                        let entryModel = AnalyticsEntryModel.from(entry)
                        context.insert(entryModel)
                    }
                }
            }
        }

        try context.save()

        if let currentId = currentWorkoutId {
            defaults.set(currentId.uuidString, forKey: currentWorkoutKey)
        }
        if let defaultId = defaultWorkoutId {
            defaults.set(defaultId.uuidString, forKey: defaultWorkoutKey)
        }
    }

    private static func loadLegacyWorkouts(defaults: UserDefaults) -> [Workout] {
        guard let data = defaults.data(forKey: workoutsKey) else { return [] }
        do {
            return try JSONDecoder().decode([Workout].self, from: data)
        } catch {
            logger.error("Failed to decode legacy workouts: \(error)")
            return []
        }
    }

    private static func loadLegacyExercises(
        workoutId: UUID,
        category: MuscleCategoryGroup,
        userId: String,
        documentsDir: URL,
        isFirstWorkout: Bool
    ) -> [Exercise] {
        let workoutFile = documentsDir.appendingPathComponent(
            "workout_\(workoutId.uuidString)_\(category.rawValue)_\(userId).json"
        )

        if FileManager.default.fileExists(atPath: workoutFile.path),
           let data = try? Data(contentsOf: workoutFile),
           let exercises = try? JSONDecoder().decode([Exercise].self, from: data) {
            return exercises
        }

        if isFirstWorkout {
            let legacyFile = documentsDir.appendingPathComponent(
                "exercises_\(category.rawValue)_\(userId).json"
            )
            if FileManager.default.fileExists(atPath: legacyFile.path),
               let data = try? Data(contentsOf: legacyFile),
               let exercises = try? JSONDecoder().decode([Exercise].self, from: data) {
                return exercises
            }
        }

        return []
    }

    private static func loadLegacyAnalytics(
        exerciseId: UUID,
        userId: String,
        documentsDir: URL
    ) -> [AnalyticsEntry] {
        let file = documentsDir.appendingPathComponent(
            "analytics_\(exerciseId)_\(userId).json"
        )

        guard FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([AnalyticsEntry].self, from: data)) ?? []
    }

    private static func legacyFilesExist(in documentsDir: URL) -> Bool {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: documentsDir.path) else {
            return false
        }
        return files.contains { $0.hasPrefix("workout_") || $0.hasPrefix("exercises_") || $0.hasPrefix("analytics_") }
    }
}
