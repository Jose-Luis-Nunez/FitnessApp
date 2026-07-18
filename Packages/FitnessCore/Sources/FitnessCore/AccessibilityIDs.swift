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

public enum WorkoutIDs {
    public static let tilePrefix = "id_workouts_tile_"
    public static let settingsPrefix = "id_workouts_settings_"
    public static let createTypePicker = "id_workouts_create_type_picker"
    public static func tile(_ id: UUID) -> String { "\(tilePrefix)\(id.uuidString)" }
    public static func settings(_ id: UUID) -> String { "\(settingsPrefix)\(id.uuidString)" }
}

public enum BottomBarIDs {
    public static let contextMenu = "id_bottom_context_menu"
    public static let workoutsTab = "id_bottom_tab_workouts"
    public static let trainingTab = "id_bottom_tab_training"
    public static let analyticsTab = "id_bottom_tab_analytics"
    public static let scheduleTab = "id_bottom_tab_schedule"
    public static let profileTab = "id_bottom_tab_profile"
}

public enum ExerciseCardIDs {
    public static func completedCard(_ id: UUID) -> String { "id_card_completed_\(id.uuidString)" }
    public static func activeCard(_ id: UUID) -> String { "id_card_active_\(id.uuidString)" }
    public static func idleCard(_ id: UUID) -> String { "id_card_idle_\(id.uuidString)" }
    public static let completedCardPrefix = "id_card_completed_"
    public static let activeCardPrefix = "id_card_active_"
    public static let idleCardPrefix = "id_card_idle_"

    /// Body/muscle icon that opens the seat editor on the active and completed
    /// cards. Shared by both variants (they never render for the same exercise
    /// simultaneously).
    public static func seatEditIcon(_ id: UUID) -> String { "id_card_seat_edit_icon_\(id.uuidString)" }
    public static let seatEditIconPrefix = "id_card_seat_edit_icon_"

    /// Leading radio button shown while the deactivate/activate multi-select
    /// mode is active.
    public static func selectionToggle(_ id: UUID) -> String { "id_card_selection_toggle_\(id.uuidString)" }
    public static let selectionTogglePrefix = "id_card_selection_toggle_"
}
