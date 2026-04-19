import Foundation
import Observation
import FitnessCore
import FitnessStorage
import Factory

@Observable
@MainActor
public final class FeedbackViewModel {
    // MARK: - State
    public var energyLevel: Int?
    public var painRegions: Set<BodyRegion> = []
    public var symptoms: Set<Symptom> = []
    public var note: String = ""

    public let exerciseId: UUID
    /// Identifies the training session this view model is bound to. All saves
    /// from this VM go to the same session row in storage; opening the sheet
    /// from a fresh exercise start gets a fresh `sessionId` from the
    /// `TrainingCoordinator` and therefore a fresh storage row.
    public let sessionId: UUID
    /// The body category is derived from the exercise at construction time and
    /// does not change during the sheet lifecycle — the training session is
    /// always scoped to a specific muscle category.
    public let painCategory: BodyCategory

    /// Stable identity for the in-flight feedback record. Reused across
    /// autosave + save calls so that re-saving from the same open sheet does
    /// not create a duplicate row. Initialised to `UUID()` and then
    /// overwritten if `prepopulate` finds an existing record for this session.
    private var feedbackId: UUID = UUID()

    /// In-memory draft store, owned by `TrainingCoordinator`. Optional purely
    /// for backward-compatibility with the older `init` (used by previews and
    /// tests that don't care about draft behaviour).
    private let draftStore: ExerciseFeedbackDraftStore?

    /// Used by `autosaveDraft()` to verify that this view-model's exercise is
    /// still the focused one before writing to the draft store. Without this,
    /// a late-firing `.onChange` after the user already switched exercises
    /// could resurrect a draft for the previous exercise.
    private let currentFocusedExerciseId: () -> UUID?

    @ObservationIgnored @Injected(\.saveFeedbackUseCase)
    private var saveFeedbackUseCase: SaveFeedbackUseCase

    @ObservationIgnored @Injected(\.feedbackStorage)
    private var feedbackStorage: FeedbackStoring

    public init(
        exerciseId: UUID,
        sessionId: UUID = UUID(),
        exerciseCategory: MuscleCategoryGroup? = nil,
        draftStore: ExerciseFeedbackDraftStore? = nil,
        currentFocusedExerciseId: @escaping () -> UUID? = { nil }
    ) {
        self.exerciseId = exerciseId
        self.sessionId = sessionId
        self.painCategory = exerciseCategory.map { BodyCategory.from(muscleGroup: $0) } ?? .back
        self.draftStore = draftStore
        self.currentFocusedExerciseId = currentFocusedExerciseId
        prepopulate()
    }

    /// Hydrates the form. Resolution order:
    /// 1. Existing committed record for this session — the user already saved
    ///    from this session and re-opens the sheet to edit. Reusing the same
    ///    `feedbackId` ensures the next save updates the row instead of
    ///    inserting a duplicate.
    /// 2. In-memory draft for this exercise — the user closed the sheet via
    ///    Hide/X/Swipe but never saved.
    /// 3. Blank form.
    /// **Not** in this list: "latest committed feedback for this exercise" —
    /// a fresh session must start blank, even when prior sessions of the same
    /// exercise were saved earlier today (analytics-style semantics).
    private func prepopulate() {
        let sessionFeedback = feedbackStorage
            .load(for: exerciseId)
            .first { $0.sessionId == sessionId }
        if let sessionFeedback {
            apply(feedback: sessionFeedback)
            return
        }
        if let draft = draftStore?.draft(for: exerciseId) {
            apply(feedback: draft)
            return
        }
        feedbackId = UUID()
    }

    private func apply(feedback: ExerciseFeedback) {
        feedbackId = feedback.id
        energyLevel = feedback.energyLevel
        painRegions = feedback.painRegions
        symptoms = feedback.symptoms
        note = feedback.note ?? ""
    }

    // MARK: - Derived

    public var availableRegions: [BodyRegion] {
        BodyRegion.regions(in: painCategory)
    }

    public var isSaveEnabled: Bool {
        energyLevel != nil
            || symptoms.isEmpty == false
            || painRegions.isEmpty == false
            || note.isEmpty == false
    }

    // MARK: - Mutations

    public func toggleSymptom(_ symptom: Symptom) {
        if symptoms.contains(symptom) {
            symptoms.remove(symptom)
        } else {
            symptoms.insert(symptom)
        }
    }

    /// Toggles a region in the pain-region selection. Mirrors `toggleSymptom`.
    public func togglePainRegion(_ region: BodyRegion) {
        if painRegions.contains(region) {
            painRegions.remove(region)
        } else {
            painRegions.insert(region)
        }
    }

    // MARK: - Draft autosave

    /// Persists the current form state to the in-memory draft store. Called
    /// from the view on every relevant `.onChange`. No-op if:
    /// - There is no draft store (legacy init path).
    /// - The view-model's exercise is no longer the focused one (defensive
    ///   guard against late `.onChange` firings after focus has moved on).
    /// When the form has no content, the draft is cleared so the icon falls
    /// back to `.entry`.
    public func autosaveDraft() {
        guard let draftStore else { return }
        guard currentFocusedExerciseId() == exerciseId else { return }
        let feedback = buildFeedback()
        if feedback.hasAnyContent {
            draftStore.setDraft(feedback)
        } else {
            draftStore.clear()
        }
    }

    // MARK: - Persistence

    /// Builds and persists the feedback. Returns the saved model, or `nil`
    /// when the form contained no user-entered data (in which case nothing is
    /// written to storage). On a successful save the in-memory draft is
    /// cleared — from this moment on the committed Done is the source of truth
    /// for this exercise.
    @discardableResult
    public func save() -> ExerciseFeedback? {
        let feedback = buildFeedback()
        let persisted = saveFeedbackUseCase.execute(feedback)
        guard persisted else { return nil }
        draftStore?.clear()
        return feedback
    }

    /// Builds an `ExerciseFeedback` from the current form state, reusing
    /// `feedbackId` and `sessionId` so all writes (draft + commit) stay on
    /// the same row identity in storage.
    private func buildFeedback() -> ExerciseFeedback {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return ExerciseFeedback(
            id: feedbackId,
            sessionId: sessionId,
            exerciseId: exerciseId,
            energyLevel: energyLevel,
            painCategory: painRegions.isEmpty ? nil : painCategory,
            painRegions: painRegions,
            symptoms: symptoms,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
    }
}
