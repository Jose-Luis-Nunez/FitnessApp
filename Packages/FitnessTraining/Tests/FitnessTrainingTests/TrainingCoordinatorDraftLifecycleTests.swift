import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessAnalytics
import FitnessTestSupport

@Suite("TrainingCoordinator draft lifecycle", .tags(.fast))
@MainActor
struct TrainingCoordinatorDraftLifecycleTests {

    private func makeSUT() -> TrainingCoordinator {
        TrainingCoordinator(
            findCategory: { _ in .chest },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in },
            analyticsViewModel: AnalyticsViewModel(storageService: StubAnalyticsStorage())
        )
    }

    private func feedback(for exerciseId: UUID, energy: Int = 3) -> ExerciseFeedback {
        ExerciseFeedback(exerciseId: exerciseId, energyLevel: energy)
    }

    @Test func switchingActiveExerciseDiscardsDraftOfPreviousExercise() {
        let sut = makeSUT()
        let exerciseA = makeExercise()
        let exerciseB = makeExercise()
        sut.startTraining(for: exerciseA)
        sut.draftStore.setDraft(feedback(for: exerciseA.id))

        sut.startTraining(for: exerciseB)

        #expect(sut.draftStore.current == nil)
    }

    @Test func cancelTrainingDiscardsActiveDraft() {
        let sut = makeSUT()
        let exercise = makeExercise()
        sut.startTraining(for: exercise)
        sut.draftStore.setDraft(feedback(for: exercise.id))

        sut.cancelTraining()

        #expect(sut.draftStore.current == nil)
    }

    @Test func cancelTrainingForExerciseDiscardsActiveDraftWhenItIsTheFocused() {
        let sut = makeSUT()
        let exercise = makeExercise()
        sut.startTraining(for: exercise)
        sut.draftStore.setDraft(feedback(for: exercise.id))

        sut.cancelTraining(for: exercise.id)

        #expect(sut.draftStore.current == nil)
    }

    @Test func finishExerciseDiscardsActiveDraft() {
        let sut = makeSUT()
        let exercise = makeExercise()
        sut.startTraining(for: exercise)
        sut.draftStore.setDraft(feedback(for: exercise.id))

        sut.finishExercise()

        #expect(sut.draftStore.current == nil)
    }

    @Test func finishExerciseForExerciseDiscardsActiveDraftWhenItIsTheFocused() {
        let sut = makeSUT()
        let exercise = makeExercise()
        sut.startTraining(for: exercise)
        sut.draftStore.setDraft(feedback(for: exercise.id))

        sut.finishExercise(for: exercise.id)

        #expect(sut.draftStore.current == nil)
    }

    @Test func resetExerciseDiscardsActiveDraft() {
        let sut = makeSUT()
        let exercise = makeExercise()
        sut.startTraining(for: exercise)
        sut.draftStore.setDraft(feedback(for: exercise.id))

        sut.resetExercise()

        #expect(sut.draftStore.current == nil)
    }

    @Test func setCurrentExerciseToNilDiscardsActiveDraft() {
        let sut = makeSUT()
        let exercise = makeExercise()
        sut.setCurrentExercise(exercise)
        sut.draftStore.setDraft(feedback(for: exercise.id))

        sut.setCurrentExercise(nil)

        #expect(sut.draftStore.current == nil)
    }
}
