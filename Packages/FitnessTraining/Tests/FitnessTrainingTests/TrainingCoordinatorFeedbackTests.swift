import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessAnalytics
import FitnessTestSupport
import Factory

@Suite("TrainingCoordinator feedback sheet", .tags(.fast))
@MainActor
struct TrainingCoordinatorFeedbackTests {

    private func makeSUT() -> TrainingCoordinator {
        Container.shared.reset()
        return TrainingCoordinator(
            findCategory: { _ in .chest },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in },
            analyticsViewModel: AnalyticsViewModel(storageService: StubAnalyticsStorage())
        )
    }

    @Test func openFeedbackFailsWithoutCurrentExercise() {
        let sut = makeSUT()
        sut.openFeedback()
        #expect(sut.isFeedbackSheetPresented == false)
    }

    @Test func openFeedbackSetsFlagWhenExerciseActive() {
        let sut = makeSUT()
        sut.startTraining(for: makeExercise())
        sut.openFeedback()
        #expect(sut.isFeedbackSheetPresented == true)
    }

    @Test func closeFeedbackClearsFlag() {
        let sut = makeSUT()
        sut.startTraining(for: makeExercise())
        sut.openFeedback()
        sut.closeFeedback()
        #expect(sut.isFeedbackSheetPresented == false)
    }
}
