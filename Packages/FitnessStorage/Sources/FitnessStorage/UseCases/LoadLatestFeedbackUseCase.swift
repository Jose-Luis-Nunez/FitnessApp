import Foundation
import FitnessCore
import Factory

/// Resolves the most recently saved `ExerciseFeedback` for a given exercise.
/// Used by `FeedbackViewModel` to pre-populate the feedback sheet when it is
/// re-opened so the user sees their previous entries instead of a blank form.
@MainActor
public struct LoadLatestFeedbackUseCase {
    @Injected(\.feedbackStorage) private var feedbackStorage

    public init() {}

    public func execute(for exerciseId: UUID) -> ExerciseFeedback? {
        feedbackStorage.latest(for: exerciseId)
    }
}
