import Foundation
import SwiftData

/// V4: `ExerciseModel` gains `isActive: Bool?` (deactivate/reactivate feature).
/// Optional so the lightweight V3→V4 step adds the column as `NULL` for existing
/// rows without a backfill — an absent value is read as active (`isActive ?? true`).
///
/// Per ADR-0005 § Snapshot requirement (hybrid rule): V4 is the current live
/// schema and therefore references exclusively the live classes in `Models/`.
/// The pre-`isActive` form is frozen in `SchemaV2` (and reused by `SchemaV3`).
enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutModel.self,
            ExerciseModel.self,
            SetProgressModel.self,
            AnalyticsEntryModel.self,
            ExerciseFeedbackModel.self,
            FriendModel.self
        ]
    }
}
