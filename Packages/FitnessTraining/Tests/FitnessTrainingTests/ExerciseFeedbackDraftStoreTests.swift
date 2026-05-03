import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessTestSupport

@Suite("ExerciseFeedbackDraftStore", .tags(.fast))
@MainActor
struct ExerciseFeedbackDraftStoreTests {

    private func makeFeedback(exerciseId: UUID = UUID(), energy: Int = 3) -> ExerciseFeedback {
        ExerciseFeedback(exerciseId: exerciseId, energyLevel: energy)
    }

    @Test func setDraftStoresFeedback() {
        let store = ExerciseFeedbackDraftStore()
        let feedback = makeFeedback()

        store.setDraft(feedback)

        #expect(store.current == feedback)
        #expect(store.draft(for: feedback.exerciseId) == feedback)
    }

    @Test func clearRemovesDraft() {
        let store = ExerciseFeedbackDraftStore()
        store.setDraft(makeFeedback())

        store.clear()

        #expect(store.current == nil)
    }

    @Test func draftForReturnsNilForOtherExerciseId() {
        let store = ExerciseFeedbackDraftStore()
        let feedback = makeFeedback()
        store.setDraft(feedback)

        #expect(store.draft(for: UUID()) == nil)
    }

    @Test func handleActiveExerciseChangeKeepsDraftWhenSameExercise() {
        let store = ExerciseFeedbackDraftStore()
        let feedback = makeFeedback()
        store.setDraft(feedback)

        store.handleActiveExerciseChange(to: feedback.exerciseId)

        #expect(store.current == feedback)
    }

    @Test func handleActiveExerciseChangeDiscardsDraftWhenSwitchingExercise() {
        let store = ExerciseFeedbackDraftStore()
        store.setDraft(makeFeedback())

        store.handleActiveExerciseChange(to: UUID())

        #expect(store.current == nil)
    }

    @Test func handleActiveExerciseChangeDiscardsDraftWhenNoExerciseActive() {
        let store = ExerciseFeedbackDraftStore()
        store.setDraft(makeFeedback())

        store.handleActiveExerciseChange(to: nil)

        #expect(store.current == nil)
    }

    @Test func handleActiveExerciseChangeIsNoOpOnEmptyStore() {
        let store = ExerciseFeedbackDraftStore()

        store.handleActiveExerciseChange(to: UUID())

        #expect(store.current == nil)
    }
}
