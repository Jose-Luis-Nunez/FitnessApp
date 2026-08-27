import Foundation
import FitnessCore

@MainActor
public final class MockAnalyticsStorage: AnalyticsStoring, WorkoutAnalyticsBatchStoring {
    public enum LoadError: Error {
        case injected
    }

    public private(set) var savedEntries: [UUID: [AnalyticsEntry]] = [:]
    public private(set) var loadCallCount = 0
    public private(set) var loadedExerciseIDs: [UUID] = []
    public private(set) var availabilityCallCount = 0
    public private(set) var availabilityExerciseIDs: [UUID] = []
    public private(set) var latestLoadCallCount = 0
    public private(set) var latestLoadedExerciseIDs: [UUID] = []
    /// Tracked separately from `loadCallCount` so a test can tell a bounded
    /// recent-day read apart from a full-history read. Inheriting the protocol's
    /// default made the two indistinguishable, which let a card that must never
    /// pull the whole history look identical to one that does.
    public private(set) var recentLoadCallCount = 0
    public private(set) var recentLoadDayLimits: [Int] = []
    public private(set) var batchLoadCallCount = 0
    public private(set) var lastBatchExerciseIDs: [UUID] = []
    public var saveSucceeds = true
    public var singleLoadFails = false
    public var availabilityLoadFails = false
    public var latestLoadFails = false
    public var recentLoadFails = false
    public var batchLoadFails = false

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
        trackedSingleLoad(for: exerciseId)
    }

    public func loadHistory(for exerciseId: UUID) throws -> [AnalyticsEntry] {
        loadCallCount += 1
        loadedExerciseIDs.append(exerciseId)
        if singleLoadFails { throw LoadError.injected }
        return savedEntries[exerciseId] ?? []
    }

    public func hasEntries(for exerciseId: UUID) throws -> Bool {
        availabilityCallCount += 1
        availabilityExerciseIDs.append(exerciseId)
        if availabilityLoadFails { throw LoadError.injected }
        return !(savedEntries[exerciseId] ?? []).isEmpty
    }

    public func loadLatestEntry(for exerciseId: UUID) throws -> AnalyticsEntry? {
        latestLoadCallCount += 1
        latestLoadedExerciseIDs.append(exerciseId)
        if latestLoadFails { throw LoadError.injected }
        return savedEntries[exerciseId]?.max { $0.date < $1.date }
    }

    /// Bounded read, mirroring the production contract: newest first, stopping
    /// after `dayLimit` distinct training days.
    public func loadRecentEntries(
        for exerciseId: UUID,
        dayLimit: Int
    ) throws -> [AnalyticsEntry] {
        recentLoadCallCount += 1
        recentLoadDayLimits.append(dayLimit)
        if recentLoadFails { throw LoadError.injected }
        guard dayLimit > 0 else { return [] }

        let calendar = Calendar.current
        var days: [Date] = []
        var result: [AnalyticsEntry] = []
        for entry in (savedEntries[exerciseId] ?? []).sorted(by: { $0.date > $1.date }) {
            let day = calendar.startOfDay(for: entry.date)
            if !days.contains(day) {
                guard days.count < dayLimit else { break }
                days.append(day)
            }
            result.append(entry)
        }
        return result
    }

    private func trackedSingleLoad(for exerciseId: UUID) -> [AnalyticsEntry] {
        loadCallCount += 1
        loadedExerciseIDs.append(exerciseId)
        return savedEntries[exerciseId] ?? []
    }

    public func loadBatch(for exerciseIds: [UUID]) throws -> [UUID: [AnalyticsEntry]] {
        batchLoadCallCount += 1
        lastBatchExerciseIDs = exerciseIds
        if batchLoadFails { throw LoadError.injected }
        return batchResult(for: exerciseIds)
    }

    private func batchResult(for exerciseIds: [UUID]) -> [UUID: [AnalyticsEntry]] {
        var seen: Set<UUID> = []
        return Dictionary(uniqueKeysWithValues: exerciseIds.filter { seen.insert($0).inserted }.map { id in
            (id, savedEntries[id] ?? [])
        })
    }

    public func resetLoadTracking() {
        loadCallCount = 0
        loadedExerciseIDs = []
        availabilityCallCount = 0
        availabilityExerciseIDs = []
        latestLoadCallCount = 0
        latestLoadedExerciseIDs = []
        recentLoadCallCount = 0
        recentLoadDayLimits = []
        batchLoadCallCount = 0
        lastBatchExerciseIDs = []
    }
}

@MainActor
public final class StubAnalyticsStorage: AnalyticsStoring {
    public init() {}

    public func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {}
    public func load(for exerciseId: UUID) -> [AnalyticsEntry] { [] }
}
