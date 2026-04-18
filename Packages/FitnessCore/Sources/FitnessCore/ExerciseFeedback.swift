import Foundation

/// Subjective per-exercise feedback captured at the end of a training set.
/// Energy level is modelled as an optional 1...5 scale. Pain regions are only
/// meaningful when `symptoms` contains `.pain`, but the domain does not enforce
/// that — callers may choose to persist pain regions without the symptom flag.
///
/// `painRegions` is a `Set<BodyRegion>` because a single exercise can cause
/// discomfort in multiple regions at once (e.g. lower back + obliques).
public struct ExerciseFeedback: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let exerciseId: UUID
    public let date: Date
    public var energyLevel: Int?
    public var painCategory: BodyCategory?
    public var painRegions: Set<BodyRegion>
    public var symptoms: Set<Symptom>
    public var note: String?

    public init(
        id: UUID = UUID(),
        exerciseId: UUID,
        date: Date = Date(),
        energyLevel: Int? = nil,
        painCategory: BodyCategory? = nil,
        painRegions: Set<BodyRegion> = [],
        symptoms: Set<Symptom> = [],
        note: String? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.date = date
        self.energyLevel = energyLevel
        self.painCategory = painCategory
        self.painRegions = painRegions
        self.symptoms = symptoms
        self.note = note
    }

    /// True when the feedback contains at least one piece of information worth
    /// persisting. An entry without any data is considered empty and should not
    /// be saved.
    public var hasAnyContent: Bool {
        energyLevel != nil
            || painCategory != nil
            || !painRegions.isEmpty
            || !symptoms.isEmpty
            || (note?.isEmpty == false)
    }
}
