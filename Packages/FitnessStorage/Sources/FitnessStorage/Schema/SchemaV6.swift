import SwiftData

/// V6 adds the isolated `WorkoutExerciseOrderModel` table. Existing model
/// shapes are unchanged, so V5 can remain frozen as-is and migrate
/// lightweight to the additive table.
enum SchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV5.models + [WorkoutExerciseOrderModel.self]
    }
}
