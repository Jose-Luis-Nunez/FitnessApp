import Foundation
import FitnessCore

@MainActor
public final class MockTotalAnalyticsStorage: TotalAnalyticsStoring {
    private let analyticsStorage: MockAnalyticsStorage
    private let exerciseStorage: MockExerciseStorage
    private let workoutStorage: MockWorkoutStorage

    public init(
        analyticsStorage: MockAnalyticsStorage,
        exerciseStorage: MockExerciseStorage,
        workoutStorage: MockWorkoutStorage
    ) {
        self.analyticsStorage = analyticsStorage
        self.exerciseStorage = exerciseStorage
        self.workoutStorage = workoutStorage
    }

    public func loadAnalytics(for exerciseId: UUID) -> [AnalyticsEntry] {
        analyticsStorage.load(for: exerciseId)
    }

    public func loadSnapshot(for workoutId: UUID) throws -> WorkoutAnalyticsSnapshot {
        let exercises = try exerciseStorage.loadWorkoutExercises(for: workoutId)
        let entries = try analyticsStorage.loadBatch(for: exercises.map(\.id))
        return WorkoutAnalyticsSnapshot(
            workoutId: workoutId,
            exercises: exercises,
            entriesByExerciseId: entries
        )
    }

    public func loadAllAnalytics() -> [AnalyticsEntry] {
        loadAllAnalytics(for: nil)
    }

    public func loadAllAnalytics(for workoutId: UUID?) -> [AnalyticsEntry] {
        legacySnapshot(for: workoutId)?.entries ?? []
    }

    public func loadAllAnalytics(for date: Date) -> [AnalyticsEntry] {
        let all = loadAllAnalytics()
        let calendar = Calendar.current
        return all.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    public func getAllExercisesWithAnalytics() -> [Exercise] {
        getAllExercisesWithAnalytics(for: nil)
    }

    public func getAllExercisesWithAnalytics(for workoutId: UUID?) -> [Exercise] {
        guard let snapshot = legacySnapshot(for: workoutId) else { return [] }
        return snapshot.exercises.filter {
            !(snapshot.entriesByExerciseId[$0.id] ?? []).isEmpty
        }
    }

    private func legacySnapshot(for workoutId: UUID?) -> WorkoutAnalyticsSnapshot? {
        guard let targetId = workoutId ?? workoutStorage.currentWorkout?.id else {
            return nil
        }
        do {
            return try loadSnapshot(for: targetId)
        } catch {
            return nil
        }
    }
}
