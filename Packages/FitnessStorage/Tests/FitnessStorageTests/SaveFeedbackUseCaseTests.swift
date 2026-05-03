import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage
import Factory

@Suite("SaveFeedbackUseCase", .tags(.integration))
@MainActor
struct SaveFeedbackUseCaseTests {

    init() {
        TestHelpers.registerInMemoryContainer()
    }

    @Test func executeSkipsEmptyFeedback() {
        let useCase = SaveFeedbackUseCase()
        let empty = ExerciseFeedback(exerciseId: UUID())
        #expect(useCase.execute(empty) == false)
    }

    @Test func executePersistsNonEmptyFeedback() {
        let useCase = SaveFeedbackUseCase()
        let exerciseId = UUID()
        let feedback = ExerciseFeedback(
            exerciseId: exerciseId,
            energyLevel: 2,
            symptoms: [.pain]
        )

        #expect(useCase.execute(feedback) == true)

        let storage = Container.shared.feedbackStorage()
        let loaded = storage.load(for: exerciseId)
        #expect(loaded.count == 1)
        #expect(loaded.first?.energyLevel == 2)
    }
}
