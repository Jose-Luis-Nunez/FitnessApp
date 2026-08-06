import Foundation
import os
import SwiftData
import FitnessCore
import Factory

private let logger = Logger(subsystem: "FitnessStorage", category: "AnalyticsStorageService")

@MainActor
public final class AnalyticsStorageService: AnalyticsStoring, WorkoutAnalyticsBatchStoring {
    private static let readBatchSize = 200
    // Retain the CONTAINER, not just its mainContext (see FeedbackStorageService).
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }

    public init(container: ModelContainer? = nil) {
        self.modelContainer = container ?? Container.shared.modelContainer()
    }

    public func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {
        let deleteDescriptor = FetchDescriptor<AnalyticsEntryModel>(
            predicate: #Predicate<AnalyticsEntryModel> { $0.exerciseId == exerciseId }
        )

        do {
            let existing = try context.fetch(deleteDescriptor)
            for model in existing {
                context.delete(model)
            }
        } catch {
            logger.error("Failed to fetch analytics entries for deletion: \(error)")
            return
        }

        for entry in entries {
            let model = AnalyticsEntryModel.from(entry)
            context.insert(model)
        }

        saveContext()
    }

    @discardableResult
    public func appendWorkoutAnalytics(_ entries: [AnalyticsEntry]) -> Bool {
        guard !entries.isEmpty else { return true }

        for entry in entries {
            context.insert(AnalyticsEntryModel.from(entry))
        }

        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            logger.error("Failed to append workout analytics batch: \(error)")
            return false
        }
    }

    public func load(for exerciseId: UUID) -> [AnalyticsEntry] {
        do {
            return try loadHistory(for: exerciseId)
        } catch {
            logger.error("Failed to fetch analytics for exercise \(exerciseId): \(error)")
            return []
        }
    }

    public func loadHistory(for exerciseId: UUID) throws -> [AnalyticsEntry] {
        let descriptor = FetchDescriptor<AnalyticsEntryModel>(
            predicate: #Predicate<AnalyticsEntryModel> { $0.exerciseId == exerciseId },
            sortBy: [SortDescriptor(\.date)]
        )

        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func hasEntries(for exerciseId: UUID) throws -> Bool {
        var descriptor = FetchDescriptor<AnalyticsEntryModel>(
            predicate: #Predicate<AnalyticsEntryModel> { $0.exerciseId == exerciseId }
        )
        descriptor.fetchLimit = 1
        return try !context.fetchIdentifiers(descriptor).isEmpty
    }

    public func loadLatestEntry(for exerciseId: UUID) throws -> AnalyticsEntry? {
        var descriptor = FetchDescriptor<AnalyticsEntryModel>(
            predicate: #Predicate<AnalyticsEntryModel> { $0.exerciseId == exerciseId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.toDomain()
    }

    public func loadBatch(for exerciseIds: [UUID]) throws -> [UUID: [AnalyticsEntry]] {
        var seen: Set<UUID> = []
        let ids = exerciseIds.filter { seen.insert($0).inserted }
        guard !ids.isEmpty else { return [:] }

        var result = Dictionary(uniqueKeysWithValues: ids.map { ($0, [AnalyticsEntry]()) })

        for start in stride(from: 0, to: ids.count, by: Self.readBatchSize) {
            let end = min(start + Self.readBatchSize, ids.count)
            let batch = Array(ids[start..<end])
            let descriptor = FetchDescriptor<AnalyticsEntryModel>(
                predicate: #Predicate<AnalyticsEntryModel> {
                    batch.contains($0.exerciseId)
                },
                sortBy: [SortDescriptor(\.date)]
            )
            for model in try context.fetch(descriptor) {
                result[model.exerciseId, default: []].append(model.toDomain())
            }
        }
        return result
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save context: \(error)")
        }
    }
}
