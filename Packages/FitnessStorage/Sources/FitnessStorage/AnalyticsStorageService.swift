import Foundation
import os
import SwiftData
import FitnessCore
import Factory

private let logger = Logger(subsystem: "FitnessStorage", category: "AnalyticsStorageService")

@MainActor
public final class AnalyticsStorageService: AnalyticsStoring {
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
        }

        for entry in entries {
            let model = AnalyticsEntryModel.from(entry)
            context.insert(model)
        }

        saveContext()
    }

    public func load(for exerciseId: UUID) -> [AnalyticsEntry] {
        let descriptor = FetchDescriptor<AnalyticsEntryModel>(
            predicate: #Predicate<AnalyticsEntryModel> { $0.exerciseId == exerciseId },
            sortBy: [SortDescriptor(\.date)]
        )

        do {
            let models = try context.fetch(descriptor)
            return models.map { $0.toDomain() }
        } catch {
            logger.error("Failed to fetch analytics for exercise \(exerciseId): \(error)")
            return []
        }
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save context: \(error)")
        }
    }
}
