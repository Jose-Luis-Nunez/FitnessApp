import Foundation
import SwiftData
import FitnessCore

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

    var workout: WorkoutModel?

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
        workout: WorkoutModel? = nil
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
