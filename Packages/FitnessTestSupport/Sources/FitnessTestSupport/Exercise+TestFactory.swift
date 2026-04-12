import Foundation
import FitnessCore

public func makeExercise(
    id: UUID = UUID(),
    name: String = "Curl",
    weight: Double = 20,
    reps: Int = 10,
    sets: Int = 3,
    seatSetting: String? = nil,
    noSeats: Bool = false,
    isCompleted: Bool = false,
    category: MuscleCategoryGroup = .arms,
    iconName: String? = nil,
    goal: Double? = nil
) -> Exercise {
    let icon = iconName ?? category.defaultIconName
    return Exercise(
        id: id,
        name: name,
        weight: weight,
        reps: reps,
        sets: sets,
        seatSetting: seatSetting,
        noSeats: noSeats,
        isCompleted: isCompleted,
        iconName: icon,
        category: category,
        goal: goal
    )
}
