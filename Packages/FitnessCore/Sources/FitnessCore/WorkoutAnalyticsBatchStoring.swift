import Foundation

/// Atomically appends a workout-wide batch without replacing existing history.
@MainActor
public protocol WorkoutAnalyticsBatchStoring {
    @discardableResult
    func appendWorkoutAnalytics(_ entries: [AnalyticsEntry]) -> Bool
}
