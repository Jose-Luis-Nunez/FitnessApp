import Foundation
import os
import FitnessCore
import Factory

private let logger = Logger(subsystem: "FitnessStorage", category: "ExportWorkoutUseCase")

/// Builds a portable JSON representation of a workout — all exercises across
/// all categories plus the complete training history — that the user can
/// share via the iOS share sheet or copy to clipboard.
///
/// The result is pretty-printed JSON with sorted keys and ISO-8601 dates so
/// the file is human-readable and produces stable diffs.
@MainActor
public struct ExportWorkoutUseCase {
    private let exerciseStorage: ExerciseStoring
    private let totalAnalyticsStorage: TotalAnalyticsStoring

    public init(
        exerciseStorage: ExerciseStoring? = nil,
        totalAnalyticsStorage: TotalAnalyticsStoring? = nil
    ) {
        self.exerciseStorage = exerciseStorage ?? Container.shared.exerciseStorage()
        self.totalAnalyticsStorage = totalAnalyticsStorage ?? Container.shared.totalAnalyticsStorage()
    }

    public func execute(workout: Workout) throws -> String {
        var allExercises: [Exercise] = []
        for category in MuscleCategoryGroup.allCases {
            let loaded = exerciseStorage.loadForWorkout(workoutId: workout.id, category: category)
            allExercises.append(contentsOf: loaded)
        }

        let analytics = totalAnalyticsStorage.loadAllAnalytics(for: workout.id)

        let envelope = WorkoutShareEnvelope(
            workout: workout,
            exercises: allExercises,
            analytics: analytics
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data: Data
        do {
            data = try encoder.encode(envelope)
        } catch {
            logger.error("Export failed: \(error, privacy: .public)")
            throw error
        }

        guard let jsonString = String(data: data, encoding: .utf8) else {
            logger.error("Export produced non-UTF8 data — unexpected for JSON.")
            throw WorkoutShareError.invalidJSON
        }
        return jsonString
    }
}
