import Foundation
import SwiftData
import FitnessCore

/// `@_spi(PersistenceUI)` exposes this `@Model` to consumers that opt in
/// with `@_spi(PersistenceUI) import FitnessStorage`. See ADR-0002 for the
/// allowed-consumer list and the rationale (also documented on
/// `ExerciseModel`).
@_spi(PersistenceUI)
@Model
public final class WorkoutModel {
    @_spi(PersistenceUI) @Attribute(.unique) public var id: UUID
    @_spi(PersistenceUI) public var name: String
    @_spi(PersistenceUI) public var selectedCategories: [String]
    @_spi(PersistenceUI) public var createdDate: Date
    @_spi(PersistenceUI) public var lastModified: Date
    @_spi(PersistenceUI) public var isDefault: Bool

    @_spi(PersistenceUI) @Relationship(deleteRule: .cascade, inverse: \ExerciseModel.workout)
    public var exercises: [ExerciseModel]

    @_spi(PersistenceUI) public init(
        id: UUID,
        name: String,
        selectedCategories: [String],
        createdDate: Date,
        lastModified: Date,
        isDefault: Bool = false,
        exercises: [ExerciseModel] = []
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

extension WorkoutModel {
    @_spi(PersistenceUI) public func toDomain() -> Workout {
        let categories = Set(selectedCategories.compactMap { MuscleCategoryGroup(rawValue: $0) })
        return Workout(
            id: id,
            name: name,
            createdDate: createdDate,
            lastModified: lastModified,
            selectedCategories: categories.isEmpty ? Set(MuscleCategoryGroup.allCases) : categories
        )
    }

    static func from(_ workout: Workout, isDefault: Bool = false) -> WorkoutModel {
        WorkoutModel(
            id: workout.id,
            name: workout.name,
            selectedCategories: workout.selectedCategories.map(\.rawValue),
            createdDate: workout.createdDate,
            lastModified: workout.lastModified,
            isDefault: isDefault
        )
    }
}
