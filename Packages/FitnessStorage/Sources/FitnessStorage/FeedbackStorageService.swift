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

    /// Upsert by `feedback.sessionId`: if a model bound to the same training
    /// session already exists it is updated in place, otherwise a new model is
    /// inserted. Two sessions of the **same exercise** on the same day (e.g.
    /// the user starts the exercise again later) intentionally produce two
    /// separate records — analogous to how analytics keep one entry per
    /// completed session. Re-saving from the same open sheet (Done -> reopen
    /// -> edit -> Save) overwrites the session's record so there is no
    /// duplication.
    public func save(_ feedback: ExerciseFeedback) {
        let sessionId = feedback.sessionId
        let descriptor = FetchDescriptor<ExerciseFeedbackModel>(
            predicate: #Predicate<ExerciseFeedbackModel> { $0.sessionId == sessionId }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.update(from: feedback)
        } else {
            context.insert(ExerciseFeedbackModel.from(feedback))
        }
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
