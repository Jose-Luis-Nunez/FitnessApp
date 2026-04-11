import Foundation
import SwiftData
import FitnessCore

@Model
final class SetProgressModel {
    var status: String
    var currentReps: Int
    var weight: Double
    var sortOrder: Int

    var entry: AnalyticsEntryModel?

    init(
        status: String,
        currentReps: Int,
        weight: Double,
        sortOrder: Int = 0,
        entry: AnalyticsEntryModel? = nil
    ) {
        self.status = status
        self.currentReps = currentReps
        self.weight = weight
        self.sortOrder = sortOrder
        self.entry = entry
    }
}

extension SetProgressModel {
    func toDomain() -> SetProgress {
        SetProgress(
            status: SetStatus(rawValue: status) ?? .notStarted,
            currentReps: currentReps,
            weight: weight
        )
    }

    static func from(_ sp: SetProgress, sortOrder: Int = 0, entry: AnalyticsEntryModel? = nil) -> SetProgressModel {
        SetProgressModel(
            status: sp.status.rawValue,
            currentReps: sp.currentReps,
            weight: sp.weight,
            sortOrder: sortOrder,
            entry: entry
        )
    }
}
