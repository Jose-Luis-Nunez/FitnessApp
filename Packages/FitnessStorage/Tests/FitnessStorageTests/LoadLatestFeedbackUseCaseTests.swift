import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("LoadLatestFeedbackUseCase", .tags(.integration))
@MainActor
struct LoadLatestFeedbackUseCaseTests {

    private let storage: FeedbackStorageService

    init() {
        let container = TestHelpers.makeInMemoryContainer()
        storage = FeedbackStorageService(container: container)
    }

    @Test func executeReturnsNilWhenNoFeedbackExists() {
        let useCase = LoadLatestFeedbackUseCase(feedbackStorage: storage)
        #expect(useCase.execute(for: UUID()) == nil)
    }

    @Test func executeReturnsLatestFeedbackForExercise() {
        let exerciseId = UUID()

        let earlier = ExerciseFeedback(
            exerciseId: exerciseId,
            date: Date(timeIntervalSince1970: 1_000),
            energyLevel: 1,
            symptoms: [.pain]
        )
        let later = ExerciseFeedback(
            exerciseId: exerciseId,
            date: Date(timeIntervalSince1970: 2_000),
            energyLevel: 4,
            symptoms: [.dizziness],
            note: "second take"
        )
        storage.save(earlier)
        storage.save(later)

        let useCase = LoadLatestFeedbackUseCase(feedbackStorage: storage)
        let resolved = useCase.execute(for: exerciseId)

        #expect(resolved?.energyLevel == 4)
        #expect(resolved?.symptoms == [.dizziness])
        #expect(resolved?.note == "second take")
    }

    @Test func executeIgnoresFeedbackForOtherExercises() {
        let target = UUID()
        let other = UUID()

        storage.save(ExerciseFeedback(exerciseId: other, energyLevel: 5))

        let useCase = LoadLatestFeedbackUseCase(feedbackStorage: storage)
        #expect(useCase.execute(for: target) == nil)
    }
}
