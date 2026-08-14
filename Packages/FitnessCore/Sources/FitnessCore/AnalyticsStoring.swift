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
