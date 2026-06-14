import Foundation
import SwiftData

/// V2: ExerciseModel gains the denormalized FK field `workoutId: UUID?` to avoid
/// optional-chain predicates (§14a). FriendModel does not exist yet.
///
/// Per ADR-0005 § Snapshot requirement (hybrid rule) plus the relationship-closure
/// rule: `ExerciseModel` changes again in V4 (gains `isActive`), so V2/V3 must
/// reference a **snapshot** of the pre-`isActive` form — not the live class.
/// `WorkoutModel` holds the inverse relationship on `ExerciseModel`, so it must be
/// snapshotted alongside (SwiftData cannot register one live `WorkoutModel` against
/// two distinct `ExerciseModel` types). The other models
/// (`SetProgressModel`, `AnalyticsEntryModel`, `ExerciseFeedbackModel`) are outside
/// the relationship cluster and stay live refs. `SchemaV3` reuses these snapshots
/// via `SchemaV2.models + [FriendModel.self]`.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SchemaV2.WorkoutModel.self,
            SchemaV2.ExerciseModel.self,
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

        @Relationship(deleteRule: .cascade, inverse: \SchemaV2.ExerciseModel.workout)
        var exercises: [SchemaV2.ExerciseModel]

        init(
            id: UUID,
            name: String,
            selectedCategories: [String],
            createdDate: Date,
            lastModified: Date,
            isDefault: Bool = false,
            exercises: [SchemaV2.ExerciseModel] = []
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
        var workoutId: UUID?
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

        var workout: SchemaV2.WorkoutModel?

        init(
            id: UUID,
            workoutId: UUID? = nil,
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
            workout: SchemaV2.WorkoutModel? = nil
        ) {
            self.id = id
            self.workoutId = workoutId
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
