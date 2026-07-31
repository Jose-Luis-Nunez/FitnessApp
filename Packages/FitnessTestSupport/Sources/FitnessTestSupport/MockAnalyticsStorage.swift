import Foundation
import FitnessCore

@MainActor
public final class MockAnalyticsStorage: AnalyticsStoring, WorkoutAnalyticsBatchStoring {
    public private(set) var savedEntries: [UUID: [AnalyticsEntry]] = [:]
    public var saveSucceeds = true

    public init() {}

    public func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {
        guard saveSucceeds else { return }
        savedEntries[exerciseId] = entries
    }

    @discardableResult
    public func appendWorkoutAnalytics(_ entries: [AnalyticsEntry]) -> Bool {
        guard saveSucceeds else { return false }
        var updatedEntries = savedEntries
        for entry in entries {
            updatedEntries[entry.exerciseId, default: []].append(entry)
        }
        savedEntries = updatedEntries
        return true
    }

    public func load(for exerciseId: UUID) -> [AnalyticsEntry] {
        savedEntries[exerciseId] ?? []
    }
}

@MainActor
public final class StubAnalyticsStorage: AnalyticsStoring {
    public init() {}

    public func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {}
    public func load(for exerciseId: UUID) -> [AnalyticsEntry] { [] }
}
