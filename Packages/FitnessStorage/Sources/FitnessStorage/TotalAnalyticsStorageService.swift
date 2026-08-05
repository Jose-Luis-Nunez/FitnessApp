import Foundation
import FitnessCore
import Factory
import os

private let logger = Logger(subsystem: "FitnessStorage", category: "TotalAnalyticsStorageService")

@MainActor
public final class TotalAnalyticsStorageService: TotalAnalyticsStoring {
    private let analyticsStorage: AnalyticsStoring
    private let exerciseStorage: ExerciseStoring
    private let workoutStorage: WorkoutStoring

    public init(
        analyticsStorage: AnalyticsStoring? = nil,
        exerciseStorage: ExerciseStoring? = nil,
        workoutStorage: WorkoutStoring? = nil
    ) {
        self.analyticsStorage = analyticsStorage ?? Container.shared.analyticsStorage()
        self.exerciseStorage = exerciseStorage ?? Container.shared.exerciseStorage()
        self.workoutStorage = workoutStorage ?? Container.shared.workoutStorage()
    }

    public func loadAnalytics(for exerciseId: UUID) -> [AnalyticsEntry] {
        analyticsStorage.load(for: exerciseId)
    }

    public func loadSnapshot(for workoutId: UUID) throws -> WorkoutAnalyticsSnapshot {
        let exercises = try exerciseStorage.loadWorkoutExercises(for: workoutId)
        let entriesByExerciseId = try analyticsStorage.loadBatch(for: exercises.map(\.id))
        return WorkoutAnalyticsSnapshot(
            workoutId: workoutId,
            exercises: exercises,
            entriesByExerciseId: entriesByExerciseId
        )
    }

    public func loadAllAnalytics() -> [AnalyticsEntry] {
        return loadAllAnalytics(for: nil)
    }

    public func loadAllAnalytics(for workoutId: UUID?) -> [AnalyticsEntry] {
        legacySnapshot(for: workoutId)?.entries ?? []
    }

    public func loadAllAnalytics(for date: Date) -> [AnalyticsEntry] {
        let allEntries = loadAllAnalytics()
        let calendar = Calendar.current

        return allEntries.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }

    public func getAllExercisesWithAnalytics() -> [Exercise] {
        return getAllExercisesWithAnalytics(for: nil)
    }

    public func getAllExercisesWithAnalytics(for workoutId: UUID?) -> [Exercise] {
        guard let snapshot = legacySnapshot(for: workoutId) else { return [] }
        return snapshot.exercises.filter {
            !(snapshot.entriesByExerciseId[$0.id] ?? []).isEmpty
        }
    }

    private func legacySnapshot(for workoutId: UUID?) -> WorkoutAnalyticsSnapshot? {
        guard let targetWorkoutId = workoutId ?? workoutStorage.currentWorkout?.id else {
            return nil
        }
        do {
            return try loadSnapshot(for: targetWorkoutId)
        } catch {
            logger.error("Failed to load analytics snapshot for workout \(targetWorkoutId): \(error)")
            return nil
        }
    }
}
