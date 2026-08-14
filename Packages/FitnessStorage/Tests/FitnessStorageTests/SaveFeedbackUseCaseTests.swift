import Testing
import Foundation
import FitnessCore
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("SaveFeedbackUseCase", .tags(.fast))
@MainActor
struct SaveFeedbackUseCaseTests {
    private final class SpyFeedbackStorage: FeedbackStoring {
        private(set) var saved: [ExerciseFeedback] = []

        func save(_ feedback: ExerciseFeedback) { saved.append(feedback) }
        func load(for exerciseId: UUID) -> [ExerciseFeedback] { [] }
        func latest(for exerciseId: UUID) -> ExerciseFeedback? { nil }
    }

    @Test func executeSkipsEmptyFeedback() {
        let storage = SpyFeedbackStorage()
        let useCase = SaveFeedbackUseCase(feedbackStorage: storage)
        let empty = ExerciseFeedback(exerciseId: UUID())

        #expect(useCase.execute(empty) == false)
        #expect(storage.saved.isEmpty)
    }

    @Test func executePersistsNonEmptyFeedback() {
        let storage = SpyFeedbackStorage()
        let useCase = SaveFeedbackUseCase(feedbackStorage: storage)
        let feedback = ExerciseFeedback(
            exerciseId: UUID(),
            energyLevel: 2,
            symptoms: [.pain]
        )

        #expect(useCase.execute(feedback) == true)
        #expect(storage.saved == [feedback])
    }
}
