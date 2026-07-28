import Foundation
import FitnessCore

enum TrainingIDs {
    static let cancelTraining = "id_training_cancel"
    static let doneButton = "id_button_done"
    static let finishButton = "id_button_finish"
    static let startButton = "id_button_start"
    static let allDoneButton = "id_button_all_done"
    static let quickDoneButton = "id_button_quick_done"
    static func controlButton(_ text: String) -> String { "id_button_\(text.lowercased())" }
    static func repsField(set index: Int) -> String { "id_reps_set_\(index)" }
    static func quickDoneSetButton(index: Int) -> String { "id_button_quick_done_set_\(index)" }
}

enum HomeIDs {
    static func categoryTile(for group: String) -> String { "id_category_tile_\(group)" }
    static let listViewToggle = "id_home_list_view_toggle"
}

enum MuscleCategoryIDs {
    static let screen = "id_muscle_category_screen"
    static let startExercise = "id_button_start_exercise"
}

enum ExerciseIDs {
    static let nameLabel = "id_label_exercise_name"
}

enum ExerciseCardIDs {
    static func completedCard(_ id: UUID) -> String { "id_card_completed_\(id.uuidString)" }
    static func activeCard(_ id: UUID) -> String { "id_card_active_\(id.uuidString)" }
    static func idleCard(_ id: UUID) -> String { "id_card_idle_\(id.uuidString)" }
    static let completedCardPrefix = "id_card_completed_"
    static let activeCardPrefix = "id_card_active_"
    static let idleCardPrefix = "id_card_idle_"
}

enum WorkoutIDs {
    static let tilePrefix = "id_workouts_tile_"
    static let settingsPrefix = "id_workouts_settings_"
    static let createTitle = "id_workouts_create_title"
    static let createNameField = "id_workouts_create_name_field"
    static let createTypePicker = "id_workouts_create_type_picker"
    static let createSaveButton = "id_workouts_create_save_button"
}

enum WorkoutLabels {
    static let newWorkout = "New workout"
    static let typeOptions = ["Pull", "Push", "Leg", "Individual", "Full"]
}

typealias BottomBarIDs = FitnessCore.BottomBarIDs
