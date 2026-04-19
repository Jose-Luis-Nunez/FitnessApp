import Foundation
import SwiftData
import FitnessCore

@Model
final class ExerciseFeedbackModel {
    @Attribute(.unique) var id: UUID
    /// Identifies the **training session** the feedback was captured in.
    /// Optional purely so SwiftData's lightweight migration can add the column
    /// to pre-existing stores (legacy rows have no session — they are treated
    /// as "session-less" and never matched by the session-id upsert path; on
    /// the next save they get a fresh sessionId). Production code always
    /// provides a value.
    var sessionId: UUID?
    var exerciseId: UUID
    var date: Date
    var energyLevel: Int?
    var painCategoryRaw: String?
    /// Legacy single-region field from the pre-multi-select schema. Still
    /// readable so old entries merge into `painRegionsRaw` at load time, but
    /// never written — new saves go into `painRegionsRaw` exclusively.
    var painRegionRaw: String?
    /// Optional so SwiftData's lightweight migration can add the attribute to
    /// pre-existing stores (non-optional arrays without a default value fail
    /// in-place migration). Defaults to `[]` in every app-level access.
    var painRegionsRaw: [String]?
    var symptomsRaw: [String]
    var note: String?

    init(
        id: UUID,
        sessionId: UUID? = nil,
        exerciseId: UUID,
        date: Date,
        energyLevel: Int? = nil,
        painCategoryRaw: String? = nil,
        painRegionRaw: String? = nil,
        painRegionsRaw: [String]? = [],
        symptomsRaw: [String] = [],
        note: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.exerciseId = exerciseId
        self.date = date
        self.energyLevel = energyLevel
        self.painCategoryRaw = painCategoryRaw
        self.painRegionRaw = painRegionRaw
        self.painRegionsRaw = painRegionsRaw
        self.symptomsRaw = symptomsRaw
        self.note = note
    }
}

extension ExerciseFeedbackModel {
    func toDomain() -> ExerciseFeedback {
        let symptoms = Set(symptomsRaw.compactMap { Symptom(rawValue: $0) })
        // Merge legacy single-value `painRegionRaw` (if still present on an old
        // record) with the new `painRegionsRaw` array. After the first save on
        // a migrated entry the legacy field becomes redundant; for safety we
        // keep it readable until we decide to drop it.
        var regionRaws = painRegionsRaw ?? []
        if regionRaws.isEmpty, let legacy = painRegionRaw {
            regionRaws = [legacy]
        }
        let regions = Set(regionRaws.compactMap { BodyRegion(rawValue: $0) })
        return ExerciseFeedback(
            id: id,
            // Legacy rows pre-dating the sessionId column get a per-load
            // synthetic id. They will never match a current session and so
            // never trigger the upsert path — the next save for this exercise
            // simply inserts a fresh row with a real sessionId.
            sessionId: sessionId ?? UUID(),
            exerciseId: exerciseId,
            date: date,
            energyLevel: energyLevel,
            painCategory: painCategoryRaw.flatMap { BodyCategory(rawValue: $0) },
            painRegions: regions,
            symptoms: symptoms,
            note: note
        )
    }

    static func from(_ feedback: ExerciseFeedback) -> ExerciseFeedbackModel {
        ExerciseFeedbackModel(
            id: feedback.id,
            sessionId: feedback.sessionId,
            exerciseId: feedback.exerciseId,
            date: feedback.date,
            energyLevel: feedback.energyLevel,
            painCategoryRaw: feedback.painCategory?.rawValue,
            painRegionRaw: nil,
            painRegionsRaw: feedback.painRegions.map { $0.rawValue }.sorted(),
            symptomsRaw: feedback.symptoms.map { $0.rawValue }.sorted(),
            note: feedback.note
        )
    }

    /// Updates every persisted field except `id` from the given domain value.
    /// Used by `FeedbackStorageService.save` for the upsert path so editing a
    /// committed feedback overwrites the original row instead of creating a
    /// duplicate. The legacy `painRegionRaw` is intentionally cleared on
    /// update — once a record passes through the new save flow we no longer
    /// keep the pre-migration single-region field around.
    func update(from feedback: ExerciseFeedback) {
        sessionId = feedback.sessionId
        exerciseId = feedback.exerciseId
        date = feedback.date
        energyLevel = feedback.energyLevel
        painCategoryRaw = feedback.painCategory?.rawValue
        painRegionRaw = nil
        painRegionsRaw = feedback.painRegions.map { $0.rawValue }.sorted()
        symptomsRaw = feedback.symptoms.map { $0.rawValue }.sorted()
        note = feedback.note
    }
}
