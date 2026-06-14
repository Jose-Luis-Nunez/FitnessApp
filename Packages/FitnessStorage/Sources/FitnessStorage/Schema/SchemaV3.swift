import Foundation
import SwiftData

/// V3: adds `FriendModel` for the Friends comparison feature.
/// V2 models (`WorkoutModel`, `ExerciseModel`, `SetProgressModel`,
/// `AnalyticsEntryModel`, `ExerciseFeedbackModel`) are unchanged; V3 extends
/// the list with the new isolated model. Migration V2→V3 is lightweight
/// (additive only, no relationship changes) — see `AppMigrationPlan`.
///
/// Per ADR-0005 § Snapshot-Pflicht: V3 reuses the `SchemaV2` snapshots for the
/// `ExerciseModel`/`WorkoutModel` relationship cluster (frozen at the pre-`isActive`
/// form) and adds the still-live, isolated `FriendModel`. The current live schema
/// is `SchemaV4`.
enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV2.models + [FriendModel.self]
    }
}
