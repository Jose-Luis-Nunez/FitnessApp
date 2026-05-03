import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("SaveFeedbackUseCase", .tags(.integration))
@MainActor
struct SaveFeedbackUseCaseTests {

    private let storage: FeedbackStorageService

    init() {
        let container = TestHelpers.makeInMemoryContainer()
        storage = FeedbackStorageService(container: container)
    }

    @Test func executeSkipsEmptyFeedback() {
        let useCase = SaveFeedbackUseCase(feedbackStorage: storage)
        let empty = ExerciseFeedback(exerciseId: UUID())
        #expect(useCase.execute(empty) == false)
    }

    @Test func executePersistsNonEmptyFeedback() {
        let exerciseId = UUID()
        let useCase = SaveFeedbackUseCase(feedbackStorage: storage)
        let feedback = ExerciseFeedback(
            exerciseId: exerciseId,
            energyLevel: 2,
            symptoms: [.pain]
        )

        #expect(useCase.execute(feedback) == true)

        let loaded = storage.load(for: exerciseId)
        #expect(loaded.count == 1)
        #expect(loaded.first?.energyLevel == 2)
    }
}
