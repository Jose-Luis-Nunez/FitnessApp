import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessStorage
import FitnessTestSupport
import Factory

@Suite("FeedbackViewModel")
@MainActor
struct FeedbackViewModelTests {

    init() {
        Container.shared.reset()
        Container.shared.feedbackStorage.register {
            MainActor.assumeIsolated { InMemoryFeedbackStorage() }
        }
    }

    @Test func initialPainCategoryMatchesExerciseMuscleGroup() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .legs)
        #expect(vm.painCategory == .legs)
    }

    @Test func initialPainRegionsIsEmpty() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .arms)
        #expect(vm.painRegions.isEmpty)
    }

    @Test func togglePainRegionAddsAndRemoves() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .back)
        vm.togglePainRegion(.lowerBack)
        #expect(vm.painRegions.contains(.lowerBack))
        vm.togglePainRegion(.upperBack)
        #expect(vm.painRegions == [.lowerBack, .upperBack])
        vm.togglePainRegion(.lowerBack)
        #expect(vm.painRegions == [.upperBack])
    }

    @Test func setEnergyLevelPersistsValue() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .chest)
        vm.energyLevel = 3
        #expect(vm.energyLevel == 3)
        vm.energyLevel = nil
        #expect(vm.energyLevel == nil)
    }

    @Test func toggleSymptomAddsAndRemoves() {
        let vm = FeedbackViewModel(exerciseId: UUID())
        vm.toggleSymptom(.pain)
        #expect(vm.symptoms.contains(.pain))
        vm.toggleSymptom(.pain)
        #expect(vm.symptoms.contains(.pain) == false)
    }

    @Test func isSaveEnabledRequiresAtLeastOneField() {
        let vm = FeedbackViewModel(exerciseId: UUID())
        vm.painRegions = []
        vm.note = ""
        #expect(vm.isSaveEnabled == false)

        vm.energyLevel = 2
        #expect(vm.isSaveEnabled == true)
    }

    @Test func isSaveEnabledTrueWhenOnlyPainRegionSelected() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .back)
        vm.togglePainRegion(.lowerBack)
        #expect(vm.isSaveEnabled == true)
    }

    @Test func saveSkipsWhenEmpty() {
        let vm = FeedbackViewModel(exerciseId: UUID())
        vm.painRegions = []
        vm.note = ""
        vm.symptoms = []

        #expect(vm.save() == nil)
    }

    @Test func saveReturnsPersistedFeedback() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .back)
        vm.energyLevel = 3
        vm.toggleSymptom(.pain)
        vm.togglePainRegion(.lowerBack)
        vm.togglePainRegion(.upperBack)
        vm.note = "  pain from set 2  "

        let saved = vm.save()
        #expect(saved != nil)
        #expect(saved?.energyLevel == 3)
        #expect(saved?.symptoms == [.pain])
        #expect(saved?.painRegions == [.lowerBack, .upperBack])
        #expect(saved?.painCategory == .back)
        #expect(saved?.note == "pain from set 2")
    }

    @Test func saveWithoutPainRegionsDoesNotSetPainCategory() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .back)
        vm.energyLevel = 4

        let saved = vm.save()
        #expect(saved != nil)
        #expect(saved?.painRegions.isEmpty == true)
        #expect(saved?.painCategory == nil)
    }

    @Test func initRehydratesFromCommittedRecordOfSameSession() {
        // When the sheet is reopened in the same session after a Save, the VM
        // must rehydrate the form from the committed record so the user sees
        // their saved values (otherwise editing-then-resave would clobber to
        // empty).
        let exerciseId = UUID()
        let sessionId = UUID()

        let storage = Container.shared.feedbackStorage()
        storage.save(ExerciseFeedback(
            sessionId: sessionId,
            exerciseId: exerciseId,
            energyLevel: 4,
            painCategory: .back,
            painRegions: [.lowerBack],
            symptoms: [.pain],
            note: "felt off on set 3"
        ))

        let vm = FeedbackViewModel(
            exerciseId: exerciseId,
            sessionId: sessionId,
            exerciseCategory: .back
        )

        #expect(vm.energyLevel == 4)
        #expect(vm.painRegions == [.lowerBack])
        #expect(vm.symptoms == [.pain])
        #expect(vm.note == "felt off on set 3")
    }

    @Test func initLeavesStateBlankWhenNoCommittedRecordForSession() {
        // Negative control for the per-session prepopulate: a previously
        // committed feedback for a *different* session of the same exercise
        // must NOT bleed into a fresh session's form. This is the analytics
        // semantic: every session starts blank.
        let exerciseId = UUID()
        let storage = Container.shared.feedbackStorage()
        storage.save(ExerciseFeedback(
            sessionId: UUID(),  // different session
            exerciseId: exerciseId,
            energyLevel: 4,
            symptoms: [.pain]
        ))

        let vm = FeedbackViewModel(
            exerciseId: exerciseId,
            sessionId: UUID(),  // fresh session
            exerciseCategory: .back
        )

        #expect(vm.energyLevel == nil)
        #expect(vm.symptoms.isEmpty)
    }

    @Test func initLeavesStateBlankWhenNoFeedbackExists() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .back)
        #expect(vm.energyLevel == nil)
        #expect(vm.painRegions.isEmpty)
        #expect(vm.symptoms.isEmpty)
        #expect(vm.note.isEmpty)
    }

    // MARK: - Draft integration

    @Test func prepopulatesFromDraftWhenAvailable() {
        let exerciseId = UUID()
        let draftStore = ExerciseFeedbackDraftStore()
        draftStore.setDraft(ExerciseFeedback(
            exerciseId: exerciseId,
            energyLevel: 2,
            symptoms: [.dizziness],
            note: "draft text"
        ))

        let vm = FeedbackViewModel(
            exerciseId: exerciseId,
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { exerciseId }
        )

        #expect(vm.energyLevel == 2)
        #expect(vm.symptoms == [.dizziness])
        #expect(vm.note == "draft text")
    }

    @Test func prepopulatesFromCommittedSessionWhenNoDraft() {
        let exerciseId = UUID()
        let sessionId = UUID()
        let storage = Container.shared.feedbackStorage()
        storage.save(ExerciseFeedback(
            sessionId: sessionId, exerciseId: exerciseId, energyLevel: 5, symptoms: [.pain]
        ))
        let draftStore = ExerciseFeedbackDraftStore()

        let vm = FeedbackViewModel(
            exerciseId: exerciseId,
            sessionId: sessionId,
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { exerciseId }
        )

        #expect(vm.energyLevel == 5)
        #expect(vm.symptoms == [.pain])
    }

    @Test func prepopulatesFromDraftWhenSessionHasNoCommittedYet() {
        // Sheet was opened, edited, hidden (draft kept), then reopened without
        // ever hitting Save. Reopening must show the draft, not blank.
        let exerciseId = UUID()
        let draftStore = ExerciseFeedbackDraftStore()
        draftStore.setDraft(ExerciseFeedback(
            exerciseId: exerciseId,
            energyLevel: 4,
            note: "in progress"
        ))

        let vm = FeedbackViewModel(
            exerciseId: exerciseId,
            sessionId: UUID(),  // session has no committed record yet
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { exerciseId }
        )

        #expect(vm.energyLevel == 4)
        #expect(vm.note == "in progress")
    }

    @Test func reopeningInSameSessionAfterSaveRehydratesFromCommitted() {
        // End-to-end: save inside session A, reopen sheet inside the same
        // session A (same sessionId) -> values come back. Different sessionId
        // (= new session) would start blank.
        let exerciseId = UUID()
        let sessionId = UUID()
        let draftStore = ExerciseFeedbackDraftStore()
        let firstVM = FeedbackViewModel(
            exerciseId: exerciseId,
            sessionId: sessionId,
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { exerciseId }
        )
        firstVM.energyLevel = 4
        firstVM.toggleSymptom(.nausea)
        _ = firstVM.save()

        let reopenedVM = FeedbackViewModel(
            exerciseId: exerciseId,
            sessionId: sessionId,
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { exerciseId }
        )

        #expect(reopenedVM.energyLevel == 4)
        #expect(reopenedVM.symptoms == [.nausea])
    }

    @Test func mutationWritesToDraftStore() {
        let exerciseId = UUID()
        let draftStore = ExerciseFeedbackDraftStore()
        let vm = FeedbackViewModel(
            exerciseId: exerciseId,
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { exerciseId }
        )

        vm.energyLevel = 3
        vm.autosaveDraft()

        #expect(draftStore.current?.energyLevel == 3)
        #expect(draftStore.current?.exerciseId == exerciseId)
    }

    @Test func autosaveSkipsWhenFocusedExerciseChanged() {
        let exerciseId = UUID()
        let draftStore = ExerciseFeedbackDraftStore()
        let vm = FeedbackViewModel(
            exerciseId: exerciseId,
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { UUID() }   // never matches
        )

        vm.energyLevel = 2
        vm.autosaveDraft()

        #expect(draftStore.current == nil)
    }

    @Test func saveClearsDraftAndPersistsCommitted() {
        let exerciseId = UUID()
        let draftStore = ExerciseFeedbackDraftStore()
        let vm = FeedbackViewModel(
            exerciseId: exerciseId,
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { exerciseId }
        )

        vm.energyLevel = 4
        vm.autosaveDraft()
        #expect(draftStore.current != nil)

        let saved = vm.save()

        #expect(saved != nil)
        #expect(draftStore.current == nil)
        let storage = Container.shared.feedbackStorage()
        #expect(storage.latest(for: exerciseId)?.energyLevel == 4)
    }

    @Test func emptyMutationClearsDraft() {
        let exerciseId = UUID()
        let draftStore = ExerciseFeedbackDraftStore()
        let vm = FeedbackViewModel(
            exerciseId: exerciseId,
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { exerciseId }
        )

        vm.energyLevel = 3
        vm.autosaveDraft()
        #expect(draftStore.current != nil)

        vm.energyLevel = nil
        vm.autosaveDraft()

        #expect(draftStore.current == nil)
    }

    @Test func editingCommittedThenSaveUpsertsSameRowBySessionId() {
        // Re-opening a committed Done in the same session, mutating, then
        // saving must overwrite the same row (no new row). The row identity
        // for upsert is `sessionId`; the original `feedbackId` is preserved
        // by `prepopulate`.
        let exerciseId = UUID()
        let sessionId = UUID()
        let storage = Container.shared.feedbackStorage()
        let originalId = UUID()
        storage.save(ExerciseFeedback(
            id: originalId,
            sessionId: sessionId,
            exerciseId: exerciseId,
            energyLevel: 2,
            symptoms: [.pain]
        ))
        let draftStore = ExerciseFeedbackDraftStore()

        let vm = FeedbackViewModel(
            exerciseId: exerciseId,
            sessionId: sessionId,
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { exerciseId }
        )
        vm.energyLevel = 5
        vm.autosaveDraft()

        // Draft adopted the original record's id so save() flows through the
        // upsert path on the same storage row.
        #expect(draftStore.current?.id == originalId)
        #expect(draftStore.current?.sessionId == sessionId)

        _ = vm.save()

        let all = storage.load(for: exerciseId)
        #expect(all.count == 1)
        #expect(all.first?.id == originalId)
        #expect(all.first?.sessionId == sessionId)
        #expect(all.first?.energyLevel == 5)
    }

    @Test func saveInNewSessionDoesNotOverwritePreviousSessionRecord() {
        // Two sessions of the same exercise on the same day must produce
        // two storage rows — the analytics-style invariant enforced by
        // sessionId-keyed upsert.
        let exerciseId = UUID()
        let storage = Container.shared.feedbackStorage()

        let firstSessionVM = FeedbackViewModel(
            exerciseId: exerciseId,
            sessionId: UUID(),
            exerciseCategory: .back
        )
        firstSessionVM.energyLevel = 2
        _ = firstSessionVM.save()

        let secondSessionVM = FeedbackViewModel(
            exerciseId: exerciseId,
            sessionId: UUID(),
            exerciseCategory: .back
        )
        secondSessionVM.energyLevel = 5
        _ = secondSessionVM.save()

        let all = storage.load(for: exerciseId)
        #expect(all.count == 2)
        #expect(Set(all.map(\.energyLevel)) == [2, 5])
    }
}

// InMemoryFeedbackStorage is now shared from FitnessTestSupport
