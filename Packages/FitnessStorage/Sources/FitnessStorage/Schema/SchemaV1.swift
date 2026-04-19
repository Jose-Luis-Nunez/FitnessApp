import Foundation
import SwiftData

/// Initial schema — die Form in der die App vor T3 zu Usern ausgeliefert wurde.
///
/// Per ADR-0005 § Snapshot-Pflicht (Hybrid-Regel) plus Beziehungs-Closure-Regel:
/// - `ExerciseModel` wird in V2 geändert (bekommt `workoutId`) → eigene Snapshot-Kopie.
/// - `WorkoutModel` hält eine Inverse-Relationship auf `ExerciseModel`. SwiftData
///   kann eine Live-`WorkoutModel`-Klasse nicht gleichzeitig auf zwei distincte
///   `ExerciseModel`-Typen (V1 + Live) registrieren — also muss `WorkoutModel` hier
///   ebenfalls snapshot't werden, obwohl seine Form selbst unverändert bleibt.
/// - Andere Models (`SetProgressModel`, `AnalyticsEntryModel`,
///   `ExerciseFeedbackModel`) sind nicht im Beziehungs-Cluster und bleiben Live-Refs.
///
/// Die Snapshot-Klassen werden nur in `Schema/`, `MigrationPlan` und
/// Migrations-Tests referenziert. App-Code nutzt weiter `ExerciseModel`,
/// `WorkoutModel` ohne Schema-Präfix (= V2-Live-Form).
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
