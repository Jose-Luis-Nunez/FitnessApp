import Foundation
import Mockable

@Mockable
@MainActor
public protocol AnalyticsStoring {
    func save(_ entries: [AnalyticsEntry], for exerciseId: UUID)
    func load(for exerciseId: UUID) -> [AnalyticsEntry]
    /// Failure-aware single-history read used by cache-backed presentation.
    func loadHistory(for exerciseId: UUID) throws -> [AnalyticsEntry]
    /// Failure-aware variant used by production snapshot and cache paths.
    /// Duplicate IDs are normalized at this storage boundary, and every
    /// requested ID is represented in the result, including empty histories.
    /// A thrown error must remain distinguishable from a successful empty read.
    func loadBatch(for exerciseIds: [UUID]) throws -> [UUID: [AnalyticsEntry]]
}

public extension AnalyticsStoring {
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
