import Foundation
import Mockable

@Mockable
@MainActor
public protocol TotalAnalyticsStoring {
    func loadAllAnalytics() -> [AnalyticsEntry]
    func loadAllAnalytics(for workoutId: UUID?) -> [AnalyticsEntry]
    func loadAllAnalytics(for date: Date) -> [AnalyticsEntry]
    func getAllExercisesWithAnalytics() -> [Exercise]
    func getAllExercisesWithAnalytics(for workoutId: UUID?) -> [Exercise]
    func loadAnalytics(for exerciseId: UUID) -> [AnalyticsEntry]
}
