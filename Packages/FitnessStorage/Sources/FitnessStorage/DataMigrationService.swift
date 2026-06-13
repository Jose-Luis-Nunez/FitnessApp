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

        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            logger.error("Failed to read legacy analytics file for \(exerciseId, privacy: .public): \(error)")
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            // Decode through the tolerant legacy shape, not the live
            // `AnalyticsEntry`: older files predate the per-set `SetProgress.id`
            // (and entry-level `id`) becoming required, so decoding with the
            // live type throws `keyNotFound("id")`. We backfill missing ids
            // instead of letting the whole file fail — and we log decode errors
            // rather than swallowing them with `try?`, which previously dropped
            // entire training histories silently on migration.
            let legacy = try decoder.decode([LegacyAnalyticsEntry].self, from: data)
            return legacy.map { entry in
                AnalyticsEntry(
                    id: entry.id ?? UUID(),
                    exerciseId: entry.exerciseId,
                    date: entry.date,
                    setProgress: entry.setProgress.map {
                        SetProgress(id: $0.id ?? UUID(), status: $0.status, currentReps: $0.currentReps, weight: $0.weight)
                    }
                )
            }
        } catch {
            logger.error("Failed to decode legacy analytics for \(exerciseId, privacy: .public): \(error)")
            return []
        }
    }

    /// Tolerant mirror of `AnalyticsEntry`/`SetProgress` as they were persisted
    /// before those types became `Identifiable` with a required `id`. Optional
    /// `id` lets pre-`id` files decode; `loadLegacyAnalytics` backfills a fresh
    /// id for any entry/set that lacks one.
    private struct LegacyAnalyticsEntry: Decodable {
        var id: UUID?
        var exerciseId: UUID
        var date: Date
        var setProgress: [LegacySetProgress]
    }

    private struct LegacySetProgress: Decodable {
        var id: UUID?
        var status: SetStatus
        var currentReps: Int
        var weight: Double
    }

    private static func legacyFilesExist(in documentsDir: URL) -> Bool {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: documentsDir.path) else {
            return false
        }
        return files.contains { $0.hasPrefix("workout_") || $0.hasPrefix("exercises_") || $0.hasPrefix("analytics_") }
    }
}
