import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessStorage
import FitnessTestSupport

@Suite("FeedbackViewModel", .tags(.fast))
@MainActor
struct FeedbackViewModelTests {

    private let storage = InMemoryFeedbackStorage()

    private func makeVM(
        exerciseId: UUID = UUID(),
        sessionId: UUID = UUID(),
        exerciseCategory: MuscleCategoryGroup? = nil,
        draftStore: ExerciseFeedbackDraftStore? = nil,
        currentFocusedExerciseId: @escaping () -> UUID? = { nil }
    ) -> FeedbackViewModel {
        FeedbackViewModel(
            exerciseId: exerciseId,
            sessionId: sessionId,
            exerciseCategory: exerciseCategory,
            draftStore: draftStore,
            currentFocusedExerciseId: currentFocusedExerciseId,
            saveFeedbackUseCase: SaveFeedbackUseCase(feedbackStorage: storage),
            feedbackStorage: storage
        )
    }

    @Test func initialPainCategoryMatchesExerciseMuscleGroup() {
        let vm = makeVM(exerciseCategory: .legs)
        #expect(vm.painCategory == .legs)
    }

    @Test func initialPainRegionsIsEmpty() {
        let vm = makeVM(exerciseCategory: .arms)
        #expect(vm.painRegions.isEmpty)
    }

    @Test func togglePainRegionAddsAndRemoves() {
        let vm = makeVM(exerciseCategory: .back)
        vm.togglePainRegion(.lowerBack)
        #expect(vm.painRegions.contains(.lowerBack))
        vm.togglePainRegion(.upperBack)
        #expect(vm.painRegions == [.lowerBack, .upperBack])
        vm.togglePainRegion(.lowerBack)
        #expect(vm.painRegions == [.upperBack])
    }

    @Test func setEnergyLevelPersistsValue() {
        let vm = makeVM(exerciseCategory: .chest)
        vm.energyLevel = 3
        #expect(vm.energyLevel == 3)
        vm.energyLevel = nil
        #expect(vm.energyLevel == nil)
    }

    @Test func toggleSymptomAddsAndRemoves() {
        let vm = makeVM()
        vm.toggleSymptom(.pain)
        #expect(vm.symptoms.contains(.pain))
        vm.toggleSymptom(.pain)
        #expect(vm.symptoms.contains(.pain) == false)
    }

    @Test func isSaveEnabledRequiresAtLeastOneField() {
        let vm = makeVM()
        vm.painRegions = []
        vm.note = ""
        #expect(vm.isSaveEnabled == false)

        vm.energyLevel = 2
        #expect(vm.isSaveEnabled == true)
    }

    @Test func isSaveEnabledTrueWhenOnlyPainRegionSelected() {
        let vm = makeVM(exerciseCategory: .back)
        vm.togglePainRegion(.lowerBack)
        #expect(vm.isSaveEnabled == true)
    }

    @Test func saveSkipsWhenEmpty() {
        let vm = makeVM()
        vm.painRegions = []
        vm.note = ""
        vm.symptoms = []

        #expect(vm.save() == nil)
    }

    @Test func saveReturnsPersistedFeedback() {
        let vm = makeVM(exerciseCategory: .back)
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
        let vm = makeVM(exerciseCategory: .back)
        vm.energyLevel = 4

        let saved = vm.save()
        #expect(saved != nil)
        #expect(saved?.painRegions.isEmpty == true)
        #expect(saved?.painCategory == nil)
    }

    @Test func initRehydratesFromCommittedRecordOfSameSession() {
        let exerciseId = UUID()
        let sessionId = UUID()

        storage.save(ExerciseFeedback(
            sessionId: sessionId,
            exerciseId: exerciseId,
            energyLevel: 4,
            painCategory: .back,
            painRegions: [.lowerBack],
            symptoms: [.pain],
            note: "felt off on set 3"
        ))

        let vm = makeVM(
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
        let exerciseId = UUID()
        storage.save(ExerciseFeedback(
            sessionId: UUID(),  // different session
            exerciseId: exerciseId,
            energyLevel: 4,
            symptoms: [.pain]
        ))

        let vm = makeVM(
            exerciseId: exerciseId,
            sessionId: UUID(),  // fresh session
            exerciseCategory: .back
        )

        #expect(vm.energyLevel == nil)
        #expect(vm.symptoms.isEmpty)
    }

    @Test func initLeavesStateBlankWhenNoFeedbackExists() {
        let vm = makeVM(exerciseCategory: .back)
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

        let vm = makeVM(
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
        storage.save(ExerciseFeedback(
            sessionId: sessionId, exerciseId: exerciseId, energyLevel: 5, symptoms: [.pain]
        ))
        let draftStore = ExerciseFeedbackDraftStore()

        let vm = makeVM(
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
        let exerciseId = UUID()
        let draftStore = ExerciseFeedbackDraftStore()
        draftStore.setDraft(ExerciseFeedback(
            exerciseId: exerciseId,
            energyLevel: 4,
            note: "in progress"
        ))

        let vm = makeVM(
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
        let exerciseId = UUID()
        let sessionId = UUID()
        let draftStore = ExerciseFeedbackDraftStore()
        let firstVM = makeVM(
            exerciseId: exerciseId,
            sessionId: sessionId,
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { exerciseId }
        )
        firstVM.energyLevel = 4
        firstVM.toggleSymptom(.nausea)
        _ = firstVM.save()

        let reopenedVM = makeVM(
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
        let vm = makeVM(
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
        let vm = makeVM(
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
        let vm = makeVM(
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
        #expect(storage.latest(for: exerciseId)?.energyLevel == 4)
    }

    @Test func emptyMutationClearsDraft() {
        let exerciseId = UUID()
        let draftStore = ExerciseFeedbackDraftStore()
        let vm = makeVM(
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
        let exerciseId = UUID()
        let sessionId = UUID()
        let originalId = UUID()
        storage.save(ExerciseFeedback(
            id: originalId,
            sessionId: sessionId,
            exerciseId: exerciseId,
            energyLevel: 2,
            symptoms: [.pain]
        ))
        let draftStore = ExerciseFeedbackDraftStore()

        let vm = makeVM(
            exerciseId: exerciseId,
            sessionId: sessionId,
            exerciseCategory: .back,
            draftStore: draftStore,
            currentFocusedExerciseId: { exerciseId }
        )
        vm.energyLevel = 5
        vm.autosaveDraft()

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
        let exerciseId = UUID()

        let firstSessionVM = makeVM(
            exerciseId: exerciseId,
            sessionId: UUID(),
            exerciseCategory: .back
        )
        firstSessionVM.energyLevel = 2
        _ = firstSessionVM.save()

        let secondSessionVM = makeVM(
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
