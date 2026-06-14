import Foundation
import SwiftData
import FitnessCore

/// `@_spi(PersistenceUI)` exposes this `@Model` to consumers that opt in
/// with `@_spi(PersistenceUI) import FitnessStorage`. Plain
/// `import FitnessStorage` callers see only the `public` service API.
///
/// Allowed consumers (per ADR-0002):
/// - `FitnessPersistenceUI` — primary integration surface
/// - `FitnessStorage`'s own tests via `@_spi(PersistenceUI) @testable import`
/// - Specific views in `FitnessExercise` that act as `@Query`-host for
///   ModelViews from `FitnessPersistenceUI` (T7a/T7b/T8a)
///
/// Every new SPI consumer outside `FitnessPersistenceUI` is a deliberate
/// boundary loosening and is review-required.
@_spi(PersistenceUI)
@Model
public final class ExerciseModel {
    @_spi(PersistenceUI) @Attribute(.unique) public var id: UUID
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
    @_spi(PersistenceUI) public var workoutId: UUID?
    @_spi(PersistenceUI) public var name: String
    @_spi(PersistenceUI) public var weight: Double
    @_spi(PersistenceUI) public var reps: Int
    @_spi(PersistenceUI) public var sets: Int
    @_spi(PersistenceUI) public var seatSetting: String?
    @_spi(PersistenceUI) public var noSeats: Bool
    @_spi(PersistenceUI) public var isCompleted: Bool
    @_spi(PersistenceUI) public var iconName: String
    @_spi(PersistenceUI) public var category: String
    @_spi(PersistenceUI) public var goal: Double?
    @_spi(PersistenceUI) public var sortOrder: Int

    /// Whether the exercise counts toward training/progress and is shown in the
    /// lists. `nil`/`true` = active, `false` = deactivated. Deactivated exercises
    /// keep all their data + history but drop out of the `"X of Y"` counts and
    /// the default list filters; they can be reactivated.
    ///
    /// Optional for the same reason as `workoutId`: SwiftData's lightweight
    /// migration step cannot validate a non-optional new property against
    /// existing rows. `nil` lets the lightweight V3→V4 step succeed without a
    /// backfill — an absent value is read as active via `isActive ?? true`.
    @_spi(PersistenceUI) public var isActive: Bool?

    @_spi(PersistenceUI) public var workout: WorkoutModel?

    @_spi(PersistenceUI) public init(
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
        self.isActive = isActive
        self.workout = workout
    }
}

extension ExerciseModel {
    @_spi(PersistenceUI) public func toDomain() -> Exercise {
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
            goal: goal,
            isActive: isActive ?? true
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
            isActive: exercise.isActive,
            workout: workout
        )
    }

    /// In-place content update: mutates the editable fields while deliberately
    /// preserving the row's identity and placement (`id`, `workoutId`, `workout`,
    /// `sortOrder`). This keeps the SwiftData row identity stable for `@Query`
    /// observers — the basis of the targeted, non-destructive update in
    /// `ExerciseStorageService.updateExercise` (ADR-0009). `category` *is* written,
    /// so an in-place category change is honoured; cross-workout moves are
    /// structurally impossible (`Exercise` carries no workout reference).
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
        isActive = exercise.isActive
    }
}
