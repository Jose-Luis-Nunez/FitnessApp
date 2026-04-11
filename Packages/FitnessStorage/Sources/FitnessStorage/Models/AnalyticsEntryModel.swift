import Foundation
import SwiftData
import FitnessCore

@Model
final class AnalyticsEntryModel {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var date: Date

    @Relationship(deleteRule: .cascade, inverse: \SetProgressModel.entry)
    var setProgressEntries: [SetProgressModel]

    init(
        id: UUID,
        exerciseId: UUID,
        date: Date,
        setProgressEntries: [SetProgressModel] = []
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.date = date
        self.setProgressEntries = setProgressEntries
    }
}

extension AnalyticsEntryModel {
    func toDomain() -> AnalyticsEntry {
        let progress = setProgressEntries
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { $0.toDomain() }
        return AnalyticsEntry(
            id: id,
            exerciseId: exerciseId,
            date: date,
            setProgress: progress
        )
    }

    static func from(_ entry: AnalyticsEntry) -> AnalyticsEntryModel {
        let model = AnalyticsEntryModel(
            id: entry.id,
            exerciseId: entry.exerciseId,
            date: entry.date
        )
        model.setProgressEntries = entry.setProgress.enumerated().map { index, sp in
            SetProgressModel.from(sp, sortOrder: index, entry: model)
        }
        return model
    }
}
