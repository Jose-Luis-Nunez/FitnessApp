import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore

@Suite("FeedbackEntryIconResolver")
@MainActor
struct FeedbackEntryIconResolverTests {

    private func resolve(
        exerciseId: UUID,
        sessionId: UUID? = UUID(),
        draft: ExerciseFeedback? = nil,
        committed: ExerciseFeedback? = nil
    ) -> FeedbackEntryIconState {
        let draftStore = ExerciseFeedbackDraftStore()
        if let draft { draftStore.setDraft(draft) }
        let storage = StubFeedbackStorage()
        if let committed { storage.entries.append(committed) }
        return FeedbackEntryIconResolver.state(
            for: exerciseId,
            sessionId: sessionId,
            draftStore: draftStore,
            storage: storage
        )
    }

    @Test func returnsEntryWhenNothingExists() {
        #expect(resolve(exerciseId: UUID()) == .entry)
    }

    @Test func returnsDraftWhenOnlyDraftExists() {
        let id = UUID()
        let draft = ExerciseFeedback(exerciseId: id, energyLevel: 3)
        #expect(resolve(exerciseId: id, draft: draft) == .draft)
    }

    @Test func returnsEntryWhenDraftIsEmpty() {
        let id = UUID()
        // Draft exists but has no content -> resolver should fall through to .entry
        let emptyDraft = ExerciseFeedback(exerciseId: id)
        #expect(resolve(exerciseId: id, draft: emptyDraft) == .entry)
    }

    @Test func returnsDraftIgnoresDraftFromOtherExercise() {
        let id = UUID()
        let otherDraft = ExerciseFeedback(exerciseId: UUID(), energyLevel: 4)
        #expect(resolve(exerciseId: id, draft: otherDraft) == .entry)
    }

    @Test func returnsDoneWhenCommittedSessionMatches() {
        let id = UUID()
        let sessionId = UUID()
        let committed = ExerciseFeedback(sessionId: sessionId, exerciseId: id, energyLevel: 5)
        #expect(resolve(exerciseId: id, sessionId: sessionId, committed: committed) == .done)
    }

    @Test func returnsEntryWhenCommittedBelongsToDifferentSession() {
        // Critical: a previous session's saved feedback must not bleed into a
        // new session's icon state. Re-starting the same exercise resets the
        // visible icon.
        let id = UUID()
        let previousSessionRecord = ExerciseFeedback(
            sessionId: UUID(), exerciseId: id, energyLevel: 5
        )
        #expect(
            resolve(exerciseId: id, sessionId: UUID(), committed: previousSessionRecord) == .entry
        )
    }

    @Test func returnsDoneEvenWhenDraftAlsoExistsForSameSession() {
        let id = UUID()
        let sessionId = UUID()
        let draft = ExerciseFeedback(exerciseId: id, energyLevel: 2)
        let committed = ExerciseFeedback(sessionId: sessionId, exerciseId: id, energyLevel: 5)
        #expect(
            resolve(exerciseId: id, sessionId: sessionId, draft: draft, committed: committed)
                == .done
        )
    }

    @Test func returnsEntryWhenSessionIdIsNil() {
        // No active session -> there can be no per-session committed record,
        // and there is no draft scope either, so the icon falls back to entry
        // (or stays at draft if a draft happens to exist for this exercise).
        let id = UUID()
        #expect(resolve(exerciseId: id, sessionId: nil) == .entry)
    }
}

@MainActor
private final class StubFeedbackStorage: FeedbackStoring {
    var entries: [ExerciseFeedback] = []

    func save(_ feedback: ExerciseFeedback) { entries.append(feedback) }
    func load(for exerciseId: UUID) -> [ExerciseFeedback] {
        entries.filter { $0.exerciseId == exerciseId }
    }
    func latest(for exerciseId: UUID) -> ExerciseFeedback? {
        load(for: exerciseId).last
    }
}
