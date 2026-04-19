import Foundation
import SwiftData
import FitnessCore

@Model
final class ExerciseModel {
    @Attribute(.unique) var id: UUID
    /// Denormalised foreign key on the workout. Replaces the old optional-chain
    /// predicate `$0.workout?.id == workoutId` (§14a anti-pattern) with the
    /// flat scalar comparison `$0.workoutId == workoutId`.
    ///
    /// Optional because SwiftData's lightweight column-add step (which runs
    /// before any custom `didMigrate`) cannot validate a non-optional new
    /// property — a default value in `init` only applies to fresh insertions,
    /// not to existing V1 rows. Optional lets the lightweight phase succeed
    /// with `NULL`; `MigrationStage.didMigrate` then backfills from `workout?.id`.
    ///
    /// Predicate-safety: comparing `UUID?` to `UUID` in `#Predicate` is **not**
    /// the §14a optional-chain anti-pattern (that requires `?.` on a relationship
    /// to traverse a join). It compiles to a flat SQL comparison and is fully
    /// indexable.
    ///
    /// Production code (`from(_:sortOrder:workout:)` helper, all save paths)
    /// always sets a real value; the `nil` state only ever exists for the
    /// brief window during a V1->V2 migration before `didMigrate` runs.
    /// TODO: add `#Index<ExerciseModel>([\.workoutId])` once min target ≥ iOS 18.
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

    var workout: WorkoutModel?

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
        workout: WorkoutModel? = nil
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

extension ExerciseModel {
    func toDomain() -> Exercise {
        Exercise(
            id: id,
            name: name,
            weight: weight,
            reps: reps,
            sets: sets,
            seatSetting: seatSetting,
            noSeats: noSeats,
            isCompleted: isCompleted,
            iconName: iconName,
            category: MuscleCategoryGroup(rawValue: category) ?? .arms,
            goal: goal
        )
    }

    static func from(_ exercise: Exercise, sortOrder: Int = 0, workout: WorkoutModel? = nil) -> ExerciseModel {
        ExerciseModel(
            id: exercise.id,
            workoutId: workout?.id,
            name: exercise.name,
            weight: exercise.weight,
            reps: exercise.reps,
            sets: exercise.sets,
            seatSetting: exercise.seatSetting,
            noSeats: exercise.noSeats,
            isCompleted: exercise.isCompleted,
            iconName: exercise.iconName,
            category: exercise.category.rawValue,
            goal: exercise.goal,
            sortOrder: sortOrder,
            workout: workout
        )
    }

    func update(from exercise: Exercise) {
        name = exercise.name
        weight = exercise.weight
        reps = exercise.reps
        sets = exercise.sets
        seatSetting = exercise.seatSetting
        noSeats = exercise.noSeats
        isCompleted = exercise.isCompleted
        iconName = exercise.iconName
        category = exercise.category.rawValue
        goal = exercise.goal
    }
}
