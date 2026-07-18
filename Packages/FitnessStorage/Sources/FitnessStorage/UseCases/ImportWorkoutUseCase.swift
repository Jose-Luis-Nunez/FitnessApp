import Foundation
import os
import FitnessCore
import Factory

private let logger = Logger(subsystem: "FitnessStorage", category: "ImportWorkoutUseCase")

/// Parses a JSON string into a `WorkoutShareEnvelope`, regenerates UUIDs for
/// the workout, all exercises, and all analytics entries, remaps each analytics
/// entry's `exerciseId` onto its new owner exercise, expands the workout's
/// selected categories to cover all imported exercises, and persists via
/// `WorkoutStoring.importWorkout(_:exercises:analytics:)`.
///
/// Throws `WorkoutShareError` for any failure — invalid JSON, unsupported
/// schema version, structurally incomplete data. Name collisions with existing
/// workouts are NOT errors — the storage layer appends a " (imported)" suffix
/// and creates a fresh workout, never overwriting.
@MainActor
public struct ImportWorkoutUseCase {
    private let workoutStorage: WorkoutStoring

    public init(workoutStorage: WorkoutStoring? = nil) {
        self.workoutStorage = workoutStorage ?? Container.shared.workoutStorage()
    }

    public func execute(jsonString: String) throws -> Workout {
        guard let data = jsonString.data(using: .utf8) else {
            throw WorkoutShareError.invalidJSON
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope: WorkoutShareEnvelope
        do {
            envelope = try decoder.decode(WorkoutShareEnvelope.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            logger.error("Import failed — dataCorrupted: \(context.debugDescription, privacy: .public)")
            throw WorkoutShareError.invalidJSON
        } catch let error as DecodingError {
            logger.error("Import failed — schema mismatch: \(String(describing: error), privacy: .public)")
            throw WorkoutShareError.schemaMismatch(detail: String(describing: error))
        } catch {
            logger.error("Import failed — decoder error: \(error, privacy: .public)")
            throw WorkoutShareError.invalidJSON
        }

        guard envelope.version >= 1 else {
            throw WorkoutShareError.unsupportedVersion(envelope.version)
        }
        guard envelope.version <= WorkoutShareEnvelope.currentVersion else {
            throw WorkoutShareError.unsupportedVersion(envelope.version)
        }

        let (remappedWorkout, remappedExercises, remappedAnalytics) = remap(envelope: envelope)

        return workoutStorage.importWorkout(
            remappedWorkout,
            exercises: remappedExercises,
            analytics: remappedAnalytics
        )
    }

    /// Assigns fresh UUIDs to workout/exercises/analytics, maps analytics
    /// entries' `exerciseId` onto the new exercise UUIDs, drops orphan
    /// analytics entries whose source exerciseId is not in the envelope, and
    /// expands the workout's selectedCategories to cover all imported exercise
    /// categories. Returns the transformed triple ready for persistence.
    private func remap(envelope: WorkoutShareEnvelope) -> (Workout, [Exercise], [AnalyticsEntry]) {
        var exerciseIdMap: [UUID: UUID] = [:]
        let newExercises = envelope.exercises.map { source -> Exercise in
            let newId = UUID()
            exerciseIdMap[source.id] = newId
            return Exercise(
                id: newId,
                name: source.name,
                weight: source.weight,
                reps: source.reps,
                sets: source.sets,
                seatSetting: source.seatSetting,
                noSeats: source.noSeats,
                isCompleted: source.isCompleted,
                iconName: source.iconName,
                category: source.category,
                goal: source.goal
            )
        }

        var droppedOrphans = 0
        let newAnalytics: [AnalyticsEntry] = envelope.analytics.compactMap { source in
            guard let newExerciseId = exerciseIdMap[source.exerciseId] else {
                droppedOrphans += 1
                return nil
            }
            return AnalyticsEntry(
                id: UUID(),
                exerciseId: newExerciseId,
                date: source.date,
                setProgress: source.setProgress
            )
        }
        if droppedOrphans > 0 {
            logger.warning("Import dropped \(droppedOrphans, privacy: .public) orphan analytics entries (exerciseId not in envelope).")
        }

        let importedCategories = Set(newExercises.map(\.category))
        let expandedCategories = envelope.workout.selectedCategories.union(importedCategories)

        let newWorkout = Workout(
            id: UUID(),
            name: envelope.workout.name,
            createdDate: envelope.workout.createdDate,
            lastModified: envelope.workout.lastModified,
            selectedCategories: expandedCategories,
            type: envelope.workout.type
        )

        return (newWorkout, newExercises, newAnalytics)
    }
}
