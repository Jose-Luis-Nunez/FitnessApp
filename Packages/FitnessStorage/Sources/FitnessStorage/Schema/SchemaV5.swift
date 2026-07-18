import SwiftData

/// V5: `WorkoutModel` gains optional `typeRaw` for the user-selected workout
/// presentation type. `nil` represents pre-V5 rows and reads as `.individual`.
/// The field is optional so V4→V5 remains a lightweight additive migration.
enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

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
