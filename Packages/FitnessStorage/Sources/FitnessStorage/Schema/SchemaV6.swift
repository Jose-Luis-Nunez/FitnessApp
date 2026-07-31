import SwiftData

/// V6 is the current development schema. The app has not shipped, so new
/// bilateral-exercise fields are added directly to the live model types rather
/// than introducing a deployment migration solely for local development data.
enum SchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV5.models + [WorkoutExerciseOrderModel.self]
    }
}
