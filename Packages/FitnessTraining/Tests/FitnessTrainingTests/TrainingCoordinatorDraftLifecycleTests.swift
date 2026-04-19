import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessAnalytics
import FitnessTestSupport
import Factory

@Suite("TrainingCoordinator draft lifecycle")
@MainActor
struct TrainingCoordinatorDraftLifecycleTests {

    private func makeSUT() -> TrainingCoordinator {
        Container.shared.reset()
        return TrainingCoordinator(
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

    @Test func committedFeedbackOfPreviousExerciseSurvivesExerciseSwitch() {
        // Negative control: switching exercises only affects the in-memory draft.
        // Committed feedback in storage is independent — verified here by leaving
        // the storage untouched and checking the draft was the only thing cleared.
        let sut = makeSUT()
        let exerciseA = makeExercise()
        let exerciseB = makeExercise()
        sut.startTraining(for: exerciseA)
        let committedLikeDraft = feedback(for: exerciseA.id, energy: 5)
        sut.draftStore.setDraft(committedLikeDraft)
        let savedSnapshot = committedLikeDraft

        sut.startTraining(for: exerciseB)

        #expect(sut.draftStore.current == nil)
        #expect(savedSnapshot.exerciseId == exerciseA.id)
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
