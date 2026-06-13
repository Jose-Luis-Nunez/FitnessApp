import Foundation
import SwiftData

/// V2: ExerciseModel gains the denormalized FK field `workoutId: UUID`
/// (`@Attribute(.indexed)`) to avoid optional-chain predicates (§14a).
///
/// Per ADR-0005 § Snapshot requirement (hybrid rule): V2 is the most recent
/// schema version and therefore references exclusively the live classes
/// in `Models/`. No snapshots, because V2 = current live state.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutModel.self,
            ExerciseModel.self,
            SetProgressModel.self,
            AnalyticsEntryModel.self,
            ExerciseFeedbackModel.self
        ]
    }
}
