import Foundation

@MainActor
public protocol FeedbackStoring {
    func save(_ feedback: ExerciseFeedback)
    func load(for exerciseId: UUID) -> [ExerciseFeedback]
    func latest(for exerciseId: UUID) -> ExerciseFeedback?
}
