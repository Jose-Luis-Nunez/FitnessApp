import Foundation

/// Accessibility identifiers aligned with `FitnessAppUITests/Selectors/AccessibilityIDs.swift`.
public enum HomeIDs {
    public static func categoryTile(for group: String) -> String { "id_category_tile_\(group)" }
}

public enum MuscleCategoryIDs {
    public static let startExercise = "id_button_start_exercise"
}

public enum ExerciseIDs {
    public static let nameLabel = "id_label_exercise_name"
}

public enum ExerciseCardIDs {
    public static func completedCard(_ id: UUID) -> String { "id_card_completed_\(id.uuidString)" }
    public static func activeCard(_ id: UUID) -> String { "id_card_active_\(id.uuidString)" }
    public static func idleCard(_ id: UUID) -> String { "id_card_idle_\(id.uuidString)" }
    public static let completedCardPrefix = "id_card_completed_"
    public static let activeCardPrefix = "id_card_active_"
    public static let idleCardPrefix = "id_card_idle_"
}
