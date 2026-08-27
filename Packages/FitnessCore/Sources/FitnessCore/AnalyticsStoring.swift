import Foundation
@MainActor
public protocol AnalyticsStoring {
    func save(_ entries: [AnalyticsEntry], for exerciseId: UUID)
    func load(for exerciseId: UUID) -> [AnalyticsEntry]
    /// Failure-aware existence read for card affordances. Production storage
    /// may answer this without materializing an AnalyticsEntry.
    func hasEntries(for exerciseId: UUID) throws -> Bool
    /// Failure-aware latest-entry read used only after a card drill-down.
    func loadLatestEntry(for exerciseId: UUID) throws -> AnalyticsEntry?
    /// Failure-aware single-history read used by cache-backed presentation.
    func loadHistory(for exerciseId: UUID) throws -> [AnalyticsEntry]
    /// Failure-aware bounded read for collapsed-card affordances that only need
    /// to compare the most recent training days. Returns the newest entries
    /// first so a caller can stop once it has seen `dayLimit` distinct days,
    /// without materializing the whole history.
    func loadRecentEntries(for exerciseId: UUID, dayLimit: Int) throws -> [AnalyticsEntry]
    /// Failure-aware variant used by production snapshot and cache paths.
    /// Duplicate IDs are normalized at this storage boundary, and every
    /// requested ID is represented in the result, including empty histories.
    /// A thrown error must remain distinguishable from a successful empty read.
    func loadBatch(for exerciseIds: [UUID]) throws -> [UUID: [AnalyticsEntry]]
}

public extension AnalyticsStoring {
    func hasEntries(for exerciseId: UUID) throws -> Bool {
        try !loadHistory(for: exerciseId).isEmpty
    }

    func loadLatestEntry(for exerciseId: UUID) throws -> AnalyticsEntry? {
        try loadHistory(for: exerciseId).max { $0.date < $1.date }
    }

    func loadHistory(for exerciseId: UUID) throws -> [AnalyticsEntry] {
        load(for: exerciseId)
    }

    /// Derives the bounded read from the full history. Production storage
    /// overrides this with a real fetch; mocks and test doubles inherit correct
    /// behaviour for free.
    func loadRecentEntries(for exerciseId: UUID, dayLimit: Int) throws -> [AnalyticsEntry] {
        guard dayLimit > 0 else { return [] }
        let calendar = Calendar.current
        let newestFirst = try loadHistory(for: exerciseId).sorted { $0.date > $1.date }

        // A plain loop rather than `prefix(while:)`: the predicate has to
        // accumulate the days seen so far, and a side-effecting predicate is
        // only correct as long as `prefix` keeps evaluating strictly in order.
        var days: [Date] = []
        var result: [AnalyticsEntry] = []
        for entry in newestFirst {
            let day = calendar.startOfDay(for: entry.date)
            if !days.contains(day) {
                guard days.count < dayLimit else { break }
                days.append(day)
            }
            result.append(entry)
        }
        return result
    }

    func loadBatch(for exerciseIds: [UUID]) throws -> [UUID: [AnalyticsEntry]] {
        Dictionary(
            uniqueKeysWithValues: try orderedUnique(exerciseIds).map { id in
                (id, try loadHistory(for: id))
            }
        )
    }

    private func orderedUnique(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}
