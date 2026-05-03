import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessAnalytics
import FitnessStorage
import FitnessTestSupport

/// End-to-end flow tests for the **per-session feedback model**.
///
/// Phases under test:
/// 1. Active session, no save -> draft state (Hide preserves it).
/// 2. Active session, explicit save -> done state, upsert by sessionId.
/// 3. Re-open same session after save -> form rehydrates from committed.
/// 4. Re-open same session, edit, save -> single record updated, no dup.
/// 5. Beenden / Cancel -> draft discarded, committed survives.
/// 6. New session of same exercise -> fresh blank, separate storage row.
///
/// Wires the real `TrainingCoordinator`, `ActiveSetViewModel`,
/// `ExerciseFeedbackDraftStore` and an `InMemoryFeedbackStorage` so the
/// session-id linkage is exercised through every layer.
@Suite("Feedback per session integration", .tags(.fast))
@MainActor
struct FeedbackPerSessionFlowTests {

    private let storage = InMemoryFeedbackStorage()

    private func makeCoordinator() -> TrainingCoordinator {
        TrainingCoordinator(
            findCategory: { _ in .chest },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in },
            analyticsViewModel: AnalyticsViewModel(storageService: StubAnalyticsStorage())
        )
    }

    private func vm(
        coordinator: TrainingCoordinator,
        exerciseId: UUID
    ) -> FeedbackViewModel {
        FeedbackViewModel(
            exerciseId: exerciseId,
            sessionId: coordinator.currentSessionId(for: exerciseId) ?? UUID(),
            exerciseCategory: .back,
            draftStore: coordinator.draftStore,
            currentFocusedExerciseId: { coordinator.focusedExerciseId },
            saveFeedbackUseCase: SaveFeedbackUseCase(feedbackStorage: storage),
            feedbackStorage: storage
        )
    }

    @Test func draftSurvivesHideAndRehydratesWithoutSaving() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)

        let firstOpen = vm(coordinator: coordinator, exerciseId: exercise.id)
        firstOpen.energyLevel = 3
        firstOpen.toggleSymptom(.dizziness)
        firstOpen.autosaveDraft()

        coordinator.closeFeedback()

        #expect(storage.load(for: exercise.id).isEmpty)
        #expect(coordinator.draftStore.current?.energyLevel == 3)

        let reopened = vm(coordinator: coordinator, exerciseId: exercise.id)
        #expect(reopened.energyLevel == 3)
        #expect(reopened.symptoms == [.dizziness])
    }

    @Test func explicitSavePromotesDraftToCommittedAndUpsertsBySession() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)
        let sessionId = coordinator.currentSessionId(for: exercise.id)
        #expect(sessionId != nil)

        let sheet = vm(coordinator: coordinator, exerciseId: exercise.id)
        sheet.energyLevel = 4
        sheet.toggleSymptom(.pain)
        _ = sheet.save()

        let rows = storage.load(for: exercise.id)
        #expect(rows.count == 1)
        #expect(rows.first?.sessionId == sessionId)
        #expect(rows.first?.energyLevel == 4)
        #expect(coordinator.draftStore.current == nil)
    }

    @Test func reopeningSameSessionAfterSaveLetsUserEditWithoutDuplicating() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)

        let firstOpen = vm(coordinator: coordinator, exerciseId: exercise.id)
        firstOpen.energyLevel = 2
        _ = firstOpen.save()

        let secondOpen = vm(coordinator: coordinator, exerciseId: exercise.id)
        #expect(secondOpen.energyLevel == 2)  // rehydrated from committed
        secondOpen.energyLevel = 5
        _ = secondOpen.save()

        let rows = storage.load(for: exercise.id)
        #expect(rows.count == 1)
        #expect(rows.first?.energyLevel == 5)
    }

    @Test func startingNewSessionAfterFinishGetsBlankFormAndKeepsPreviousRow() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)
        let firstSessionId = coordinator.currentSessionId(for: exercise.id)

        let firstOpen = vm(coordinator: coordinator, exerciseId: exercise.id)
        firstOpen.energyLevel = 3
        _ = firstOpen.save()

        coordinator.finishExercise(for: exercise.id)
        #expect(coordinator.draftStore.current == nil)

        coordinator.startTraining(for: exercise)
        let secondSessionId = coordinator.currentSessionId(for: exercise.id)
        #expect(secondSessionId != nil)
        #expect(secondSessionId != firstSessionId)

        let secondOpen = vm(coordinator: coordinator, exerciseId: exercise.id)
        #expect(secondOpen.energyLevel == nil)
        #expect(secondOpen.symptoms.isEmpty)

        secondOpen.energyLevel = 5
        _ = secondOpen.save()

        let rows = storage.load(for: exercise.id)
        #expect(rows.count == 2)
        #expect(Set(rows.map(\.energyLevel)) == [3, 5])
    }

    @Test func finishingExerciseDoesNotAutoCommitDraft() {
        let coordinator = makeCoordinator()
        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)

        let sheet = vm(coordinator: coordinator, exerciseId: exercise.id)
        sheet.energyLevel = 4
        sheet.toggleSymptom(.pain)
        sheet.autosaveDraft()

        coordinator.finishExercise(for: exercise.id)

        #expect(storage.load(for: exercise.id).isEmpty)
        #expect(coordinator.draftStore.current == nil)
    }
}

// InMemoryFeedbackStorage is now shared from FitnessTestSupport
