import Foundation

/// Accessibility identifiers shared between feature views, model-driven
/// views (`FitnessPersistenceUI`), and `FitnessAppUITests/Selectors/AccessibilityIDs.swift`.
///
/// Hoisted into `FitnessCore` as part of T7-0 so the new model-driven
/// views in `FitnessPersistenceUI` can attach the same identifiers as the
/// legacy views in `FitnessExercise` without re-introducing a dependency
/// cycle. UI tests target these strings exactly — keep in sync with the
/// selector file in the UI-test target.
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
