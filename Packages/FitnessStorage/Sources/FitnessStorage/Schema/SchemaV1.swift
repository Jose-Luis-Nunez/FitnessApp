import Foundation
import SwiftData

/// Initial schema — the form in which the app was shipped to users before T3.
///
/// Per ADR-0005 § Snapshot requirement (hybrid rule) plus relationship-closure rule:
/// - `ExerciseModel` is changed in V2 (gains `workoutId`) → its own snapshot copy.
/// - `WorkoutModel` holds an inverse relationship on `ExerciseModel`. SwiftData
///   cannot register a live `WorkoutModel` class against two distinct
///   `ExerciseModel` types (V1 + live) at the same time — so `WorkoutModel` must
///   also be snapshotted here, even though its own form remains unchanged.
/// - Other models (`SetProgressModel`, `AnalyticsEntryModel`,
///   `ExerciseFeedbackModel`) are not in the relationship cluster and stay live refs.
///
/// The snapshot classes are referenced only in `Schema/`, `MigrationPlan` and
/// migration tests. App code continues to use `ExerciseModel`,
/// `WorkoutModel` without a schema prefix (= V2 live form).
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SchemaV1.WorkoutModel.self,
            SchemaV1.ExerciseModel.self,
            SetProgressModel.self,
            AnalyticsEntryModel.self,
            ExerciseFeedbackModel.self
        ]
    }

    @Model
    final class WorkoutModel {
        @Attribute(.unique) var id: UUID
        var name: String
        var selectedCategories: [String]
        var createdDate: Date
        var lastModified: Date
        var isDefault: Bool

        @Relationship(deleteRule: .cascade, inverse: \SchemaV1.ExerciseModel.workout)
        var exercises: [SchemaV1.ExerciseModel]

        init(
            id: UUID,
            name: String,
            selectedCategories: [String],
            createdDate: Date,
            lastModified: Date,
            isDefault: Bool = false,
            exercises: [SchemaV1.ExerciseModel] = []
        ) {
            self.id = id
            self.name = name
            self.selectedCategories = selectedCategories
            self.createdDate = createdDate
            self.lastModified = lastModified
            self.isDefault = isDefault
            self.exercises = exercises
        }
    }

    @Model
    final class ExerciseModel {
        @Attribute(.unique) var id: UUID
        var name: String
        var weight: Double
        var reps: Int
        var sets: Int
        var seatSetting: String?
        var noSeats: Bool
        var isCompleted: Bool
        var iconName: String
        var category: String
        var goal: Double?
        var sortOrder: Int

        var workout: SchemaV1.WorkoutModel?

        init(
            id: UUID,
            name: String,
            weight: Double,
            reps: Int,
            sets: Int,
            seatSetting: String? = nil,
            noSeats: Bool = false,
            isCompleted: Bool = false,
            iconName: String,
            category: String,
            goal: Double? = nil,
            sortOrder: Int = 0,
            workout: SchemaV1.WorkoutModel? = nil
        ) {
            self.id = id
            self.name = name
            self.weight = weight
            self.reps = reps
            self.sets = sets
            self.seatSetting = seatSetting
            self.noSeats = noSeats
            self.isCompleted = isCompleted
            self.iconName = iconName
            self.category = category
            self.goal = goal
            self.sortOrder = sortOrder
            self.workout = workout
        }
    }
}
