import Testing
import Foundation
import SwiftData
import FitnessCore
@testable import FitnessStorage
import Factory

@Suite("LoadLatestFeedbackUseCase")
@MainActor
struct LoadLatestFeedbackUseCaseTests {

    init() {
        TestHelpers.registerInMemoryContainer()
    }

    @Test func executeReturnsNilWhenNoFeedbackExists() {
        let useCase = LoadLatestFeedbackUseCase()
        #expect(useCase.execute(for: UUID()) == nil)
    }

    @Test func executeReturnsLatestFeedbackForExercise() {
        let exerciseId = UUID()
        let storage = Container.shared.feedbackStorage()

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

        let useCase = LoadLatestFeedbackUseCase()
        let resolved = useCase.execute(for: exerciseId)

        #expect(resolved?.energyLevel == 4)
        #expect(resolved?.symptoms == [.dizziness])
        #expect(resolved?.note == "second take")
    }

    @Test func executeIgnoresFeedbackForOtherExercises() {
        let target = UUID()
        let other = UUID()
        let storage = Container.shared.feedbackStorage()

        storage.save(ExerciseFeedback(exerciseId: other, energyLevel: 5))

        let useCase = LoadLatestFeedbackUseCase()
        #expect(useCase.execute(for: target) == nil)
    }
}
