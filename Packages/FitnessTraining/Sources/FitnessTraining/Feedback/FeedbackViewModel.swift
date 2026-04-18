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
    /// The body category is derived from the exercise at construction time and
    /// does not change during the sheet lifecycle — the training session is
    /// always scoped to a specific muscle category.
    public let painCategory: BodyCategory

    @ObservationIgnored @Injected(\.saveFeedbackUseCase)
    private var saveFeedbackUseCase: SaveFeedbackUseCase

    public init(
        exerciseId: UUID,
        exerciseCategory: MuscleCategoryGroup? = nil
    ) {
        self.exerciseId = exerciseId
        self.painCategory = exerciseCategory.map { BodyCategory.from(muscleGroup: $0) } ?? .back
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

    // MARK: - Persistence

    /// Builds and persists the feedback. Returns the saved model, or `nil`
    /// when the form contained no user-entered data (in which case nothing is
    /// written to storage).
    @discardableResult
    public func save() -> ExerciseFeedback? {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let feedback = ExerciseFeedback(
            exerciseId: exerciseId,
            energyLevel: energyLevel,
            painCategory: painRegions.isEmpty ? nil : painCategory,
            painRegions: painRegions,
            symptoms: symptoms,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        let persisted = saveFeedbackUseCase.execute(feedback)
        return persisted ? feedback : nil
    }
}
