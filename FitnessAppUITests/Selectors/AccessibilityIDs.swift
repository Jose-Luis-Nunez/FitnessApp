import Foundation
import FitnessCore

enum TrainingIDs {
    static let cancelTraining = "id_training_cancel"
    static let sheet = "id_training_sheet"
    static let sheetBackdrop = "id_training_sheet_backdrop"
    static let sheetGrabber = "id_training_sheet_grabber"
    static let sheetTitle = "id_training_sheet_title"
    static let muscleIcon = "id_training_muscle_icon"
    static let setScroll = "id_training_set_scroll"
    static let doneButton = "id_button_done"
    static let finishButton = "id_button_finish"
    static let startButton = "id_button_start"
    static let allDoneButton = "id_button_all_done"
    static let quickDoneButton = "id_button_quick_done"
    static let feedbackButton = "id_button_feedback"
    static let feedbackSheet = "id_feedback_sheet"
    static let feedbackSheetBackdrop = "id_feedback_sheet_backdrop"
    static let feedbackSheetGrabber = "id_feedback_sheet_grabber"
    static func controlButton(_ text: String) -> String { "id_button_\(text.lowercased())" }
    static func repsField(set index: Int) -> String { "id_reps_set_\(index)" }
    static func repsField(logicalSet index: Int, side: String) -> String {
        "id_reps_set_\(index)_\(side)"
    }
    static func sideHeader(_ side: String) -> String { "id_training_side_\(side)" }
}

enum TrainingLabels {
    static let closeTraining = "Close training"
    static let recordSetResult = "Record set result"
    static let muscleIllustration = "Exercise muscle illustration"
}

enum WorkoutPickerIDs {
    static let dropdown = "id_workout_dropdown"
    static let overlay = "id_workout_picker"
    static let wheel = "id_workout_picker_wheel"
    static let confirmButton = "id_workout_picker_confirm"
}

enum HomeIDs {
    static func categoryTile(for group: String) -> String { "id_category_tile_\(group)" }
    static let overviewViewToggle = "id_home_overview_view_toggle"
    static let listViewToggle = "id_home_list_view_toggle"
    static let overviewContent = "id_home_overview_content"
    static let listContent = "id_home_list_content"
}

enum HomeLabels {
    static let resetAll = "Reset all"
}

enum MuscleCategoryIDs {
    static let screen = "id_muscle_category_screen"
    static let startExercise = "id_button_start_exercise"
}

enum ExerciseIDs {
    static let nameLabel = "id_label_exercise_name"
    static let nameField = "id_exercise_name_field"
    static let seatPicker = FitnessCore.ExerciseIDs.seatPicker
    static let fullEditContinueButton = "id_exercise_full_continue"
    static let fullEditSaveButton = "id_exercise_full_save"
    static let bilateralToggle = "id_exercise_bilateral_toggle"
    static let bodyweightToggle = "id_exercise_bodyweight_toggle"
    static let decimalWeightToggle = "id_exercise_decimal_weight_toggle"
}

enum ExerciseLabels {
    static let newExercise = "New Exercise"
    static let cancelAction = "Cancel"
    static let continueAction = "Continue"
    static let saveAction = "Save"
}

enum AnalyticsLabels {
    static let addData = "Add data"
    static let saveAction = "Save"
}

enum ExerciseCardIDs {
    static func completedCard(_ id: UUID) -> String { "id_card_completed_\(id.uuidString)" }
    static func activeCard(_ id: UUID) -> String { "id_card_active_\(id.uuidString)" }
    static func idleCard(_ id: UUID) -> String { "id_card_idle_\(id.uuidString)" }
    static let completedCardPrefix = "id_card_completed_"
    static let activeCardPrefix = "id_card_active_"
    static let idleCardPrefix = "id_card_idle_"
    static let seatEditIconPrefix = FitnessCore.ExerciseCardIDs.seatEditIconPrefix
    static func analytics(_ id: UUID) -> String { "id_card_analytics_\(id.uuidString)" }
    static let analyticsPrefix = "id_card_analytics_"
}

enum AnalyticsIDs {
    static let screen = "id_analytics_screen"
    static let addDataButton = "id_analytics_add_data"
    static let entryAddSetButton = "id_analytics_entry_add_set"
    static let entrySaveButton = "id_analytics_entry_save"
    static func entryWeightField(logicalSet index: Int, side: String?) -> String {
        "id_analytics_entry_weight_\(index)_\(side ?? "standard")"
    }
    static func entryRepsField(logicalSet index: Int, side: String?) -> String {
        "id_analytics_entry_reps_\(index)_\(side ?? "standard")"
    }
    static func bilateralResult(logicalSet index: Int, side: String) -> String {
        "id_analytics_set_\(index)_\(side)"
    }
}

enum WorkoutAnalyticsIDs {
    static let screen = "id_workout_analytics_screen"
    static let dateButton = "id_workout_analytics_date"
    static let saveButton = "id_workout_analytics_save"
    static let exerciseSelectionPrefix = "id_workout_analytics_selection_"
    static func exerciseSelection(_ id: UUID) -> String {
        "\(exerciseSelectionPrefix)\(id.uuidString)"
    }
    static func exerciseDetails(_ id: UUID) -> String {
        "id_workout_analytics_details_\(id.uuidString)"
    }
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
    static let addAnalytics = "Log Workout"
    static let typeOptions = ["Pull", "Push", "Leg", "Individual", "Full"]
    static let pullFixture = "Pull Fixture"
    static let legFixture = "Leg Fixture"
}

enum ProfileIDs {
    static let bodyHeader = "id_profile_body_header"
    static let bmiRefresh = "id_profile_bmi_refresh"
    static let friendsHeader = "id_friends_section_header"
    static let friendsUserRow = "id_friends_user_row"
    static let greenAccent = "id_profile_icon_color_green"
    static let greyAccent = "id_profile_icon_color_grey"
}

typealias BottomBarIDs = FitnessCore.BottomBarIDs
