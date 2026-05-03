import Foundation
import FitnessCore
import Factory

@MainActor
public struct SaveFeedbackUseCase {
    private let feedbackStorage: FeedbackStoring

    public init(feedbackStorage: FeedbackStoring? = nil) {
        self.feedbackStorage = feedbackStorage ?? Container.shared.feedbackStorage()
    }

    /// Persists the feedback if it contains any user-entered information.
    /// Returns `true` when the feedback was saved, `false` when it was empty
    /// and therefore ignored (no point persisting a blank record).
    @discardableResult
    public func execute(_ feedback: ExerciseFeedback) -> Bool {
        guard feedback.hasAnyContent else { return false }
        feedbackStorage.save(feedback)
        return true
    }
}
