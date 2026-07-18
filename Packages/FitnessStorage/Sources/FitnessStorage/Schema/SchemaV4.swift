import Foundation
import SwiftData

/// V4: `ExerciseModel` gains `isActive: Bool?`.
///
/// V5 changes the related live `WorkoutModel`, so V4 freezes the complete
/// Workout↔Exercise relationship cluster at its pre-`typeRaw` shape. Keeping
/// both sides as snapshots prevents SwiftData from registering one live model
/// against two different relationship types during migration.
enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SchemaV4.WorkoutModel.self,
            SchemaV4.ExerciseModel.self,
            SetProgressModel.self,
            AnalyticsEntryModel.self,
            ExerciseFeedbackModel.self,
            FriendModel.self
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

        @Relationship(deleteRule: .cascade, inverse: \SchemaV4.ExerciseModel.workout)
        var exercises: [SchemaV4.ExerciseModel]

        init(
            id: UUID,
            name: String,
            selectedCategories: [String],
            createdDate: Date,
            lastModified: Date,
            isDefault: Bool = false,
            exercises: [SchemaV4.ExerciseModel] = []
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
        var isActive: Bool?
        var workout: SchemaV4.WorkoutModel?

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
            isActive: Bool? = nil,
            workout: SchemaV4.WorkoutModel? = nil
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
            self.isActive = isActive
            self.workout = workout
        }
    }
}
