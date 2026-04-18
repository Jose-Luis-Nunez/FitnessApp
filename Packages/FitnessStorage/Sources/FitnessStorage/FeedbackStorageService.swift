import Foundation
import os
import SwiftData
import FitnessCore
import Factory

private let logger = Logger(subsystem: "FitnessStorage", category: "FeedbackStorageService")

@MainActor
public final class FeedbackStorageService: FeedbackStoring {
    private let context: ModelContext

    public init(container: ModelContainer? = nil) {
        let resolved = container ?? Container.shared.modelContainer()
        self.context = ModelContext(resolved)
        self.context.autosaveEnabled = true
    }

    public func save(_ feedback: ExerciseFeedback) {
        let model = ExerciseFeedbackModel.from(feedback)
        context.insert(model)
        saveContext()
    }

    public func load(for exerciseId: UUID) -> [ExerciseFeedback] {
        let descriptor = FetchDescriptor<ExerciseFeedbackModel>(
            predicate: #Predicate<ExerciseFeedbackModel> { $0.exerciseId == exerciseId },
            sortBy: [SortDescriptor(\.date)]
        )

        do {
            return try context.fetch(descriptor).map { $0.toDomain() }
        } catch {
            logger.error("Failed to fetch feedback for exercise \(exerciseId): \(error)")
            return []
        }
    }

    public func latest(for exerciseId: UUID) -> ExerciseFeedback? {
        load(for: exerciseId).last
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save feedback context: \(error)")
        }
    }
}
