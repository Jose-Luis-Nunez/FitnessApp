import Foundation
import SwiftData
import FitnessCore

@Model
final class WorkoutModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var selectedCategories: [String]
    var createdDate: Date
    var lastModified: Date
    var isDefault: Bool

    @Relationship(deleteRule: .cascade, inverse: \ExerciseModel.workout)
    var exercises: [ExerciseModel]

    init(
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
    func toDomain() -> Workout {
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
