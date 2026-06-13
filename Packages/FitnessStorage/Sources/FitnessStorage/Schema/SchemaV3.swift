import Foundation
import SwiftData

/// V3: adds `FriendModel` for the Friends comparison feature.
/// V2 models (`WorkoutModel`, `ExerciseModel`, `SetProgressModel`,
/// `AnalyticsEntryModel`, `ExerciseFeedbackModel`) are unchanged; V3 extends
/// the list with the new isolated model. Migration V2→V3 is lightweight
/// (additive only, no relationship changes) — see `AppMigrationPlan`.
///
/// Per ADR-0005 § Snapshot-Pflicht: V3 is the current live schema and
/// references the live model classes directly (no snapshots required).
enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV2.models + [FriendModel.self]
    }
}
