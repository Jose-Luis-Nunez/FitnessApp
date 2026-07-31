import Foundation
import SwiftData
import FitnessCore

@Model
final class SetProgressModel {
    var status: String
    var currentReps: Int
    var weight: Double
    var sortOrder: Int
    /// Optional execution metadata. Legacy standard sets keep both values nil.
    var sideRaw: String?
    var logicalSetIndex: Int?

    var entry: AnalyticsEntryModel?

    init(
        status: String,
        currentReps: Int,
        weight: Double,
        sortOrder: Int = 0,
        sideRaw: String? = nil,
        logicalSetIndex: Int? = nil,
        entry: AnalyticsEntryModel? = nil
    ) {
        self.status = status
        self.currentReps = currentReps
        self.weight = weight
        self.sortOrder = sortOrder
        self.sideRaw = sideRaw
        self.logicalSetIndex = logicalSetIndex
        self.entry = entry
    }
}

extension SetProgressModel {
    func toDomain() -> SetProgress {
        SetProgress(
            status: SetStatus(rawValue: status) ?? .notStarted,
            currentReps: currentReps,
            weight: weight,
            side: sideRaw.flatMap(ExerciseSide.init(rawValue:)),
            logicalSetIndex: logicalSetIndex
        )
    }

    static func from(_ sp: SetProgress, sortOrder: Int = 0, entry: AnalyticsEntryModel? = nil) -> SetProgressModel {
        SetProgressModel(
            status: sp.status.rawValue,
            currentReps: sp.currentReps,
            weight: sp.weight,
            sortOrder: sortOrder,
            sideRaw: sp.side?.rawValue,
            logicalSetIndex: sp.logicalSetIndex,
            entry: entry
        )
    }
}
