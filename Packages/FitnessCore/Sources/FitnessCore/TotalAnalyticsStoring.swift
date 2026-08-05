import Foundation
import Mockable

@Mockable
@MainActor
public protocol TotalAnalyticsStoring {
    /// Loads one coherent workout-wide analytics value. Storage failures stay
    /// distinguishable from a successfully loaded workout with no history.
    func loadSnapshot(for workoutId: UUID) throws -> WorkoutAnalyticsSnapshot
    func loadAllAnalytics() -> [AnalyticsEntry]
    func loadAllAnalytics(for workoutId: UUID?) -> [AnalyticsEntry]
    func loadAllAnalytics(for date: Date) -> [AnalyticsEntry]
    func getAllExercisesWithAnalytics() -> [Exercise]
    func getAllExercisesWithAnalytics(for workoutId: UUID?) -> [Exercise]
    func loadAnalytics(for exerciseId: UUID) -> [AnalyticsEntry]
}
