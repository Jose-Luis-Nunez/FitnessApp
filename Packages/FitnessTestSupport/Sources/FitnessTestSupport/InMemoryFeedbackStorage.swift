import Foundation
import FitnessCore

@MainActor
public final class InMemoryFeedbackStorage: FeedbackStoring {
    private var entries: [ExerciseFeedback] = []

    public init() {}

    public func save(_ feedback: ExerciseFeedback) {
        if let idx = entries.firstIndex(where: { $0.sessionId == feedback.sessionId }) {
            entries[idx] = feedback
        } else {
            entries.append(feedback)
        }
    }

    public func load(for exerciseId: UUID) -> [ExerciseFeedback] {
        entries.filter { $0.exerciseId == exerciseId }.sorted { $0.date < $1.date }
    }

    public func latest(for exerciseId: UUID) -> ExerciseFeedback? {
        load(for: exerciseId).last
    }
}
