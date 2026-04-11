import Foundation
import SwiftData
import FitnessCore
import Factory

@MainActor
public final class AnalyticsStorageService: AnalyticsStoring {
    private let context: ModelContext

    public init() {
        let container = Container.shared.modelContainer()
        self.context = ModelContext(container)
        self.context.autosaveEnabled = true
    }

    public func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {
        let deleteDescriptor = FetchDescriptor<AnalyticsEntryModel>(
            predicate: #Predicate<AnalyticsEntryModel> { $0.exerciseId == exerciseId }
        )

        if let existing = try? context.fetch(deleteDescriptor) {
            for model in existing {
                context.delete(model)
            }
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

        let models = (try? context.fetch(descriptor)) ?? []
        return models.map { $0.toDomain() }
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("AnalyticsStorageService: Failed to save context: \(error)")
        }
    }
}
