import FitnessCore
import FitnessStorage
import Factory
import Foundation

/// Appends one analytics entry per submitted exercise without collapsing
/// entries that already exist on the same calendar day.
@MainActor
public struct SaveWorkoutAnalyticsUseCase {
    private let batchStorage: WorkoutAnalyticsBatchStoring

    public init(batchStorage: WorkoutAnalyticsBatchStoring? = nil) {
        self.batchStorage = batchStorage
            ?? Container.shared.workoutAnalyticsBatchStorage()
    }

    /// - Returns: The number of persisted entries, or `nil` after a storage failure.
    @discardableResult
    public func execute(entries: [AnalyticsEntry]) -> Int? {
        let validEntries = entries.filter { !$0.setProgress.isEmpty }

        guard batchStorage.appendWorkoutAnalytics(validEntries) else {
            return nil
        }
        return validEntries.count
    }
}
