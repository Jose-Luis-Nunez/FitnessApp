import Foundation
import FitnessCore

public enum TrainingIDs {
    public static let sheet = "id_training_sheet"
    public static let sheetBackdrop = "id_training_sheet_backdrop"
    public static let sheetGrabber = "id_training_sheet_grabber"
    public static let sheetTitle = "id_training_sheet_title"
    public static let muscleIcon = "id_training_muscle_icon"
    public static let setScroll = "id_training_set_scroll"
    public static let doneButton = "id_button_done"
    public static let finishButton = "id_button_finish"
    public static let startButton = "id_button_start"
    public static let allDoneButton = "id_button_all_done"
    public static let quickDoneButton = "id_button_quick_done"
    public static let feedbackButton = "id_button_feedback"
    public static let feedbackSheet = "id_feedback_sheet"
    public static let feedbackSheetBackdrop = "id_feedback_sheet_backdrop"
    public static let feedbackSheetGrabber = "id_feedback_sheet_grabber"
    public static let feedbackSaveButton = "id_button_feedback_save"
    public static let feedbackCancelButton = "id_button_feedback_cancel"
    public static let energyLevelSlider = "id_slider_energy_level"
    public static func symptomChip(_ rawValue: String) -> String { "id_symptom_\(rawValue)" }
    public static func controlButton(_ text: String) -> String { "id_button_\(text.lowercased())" }
    public static func repsField(set index: Int) -> String { "id_reps_set_\(index)" }
    public static func repsField(logicalSet index: Int, side: ExerciseSide) -> String {
        "id_reps_set_\(index)_\(side.rawValue)"
    }
    public static func sideHeader(_ side: ExerciseSide) -> String {
        "id_training_side_\(side.rawValue)"
    }
}

public enum WorkoutPickerIDs {
    public static let dropdown = "id_workout_dropdown"
    public static let overlay = "id_workout_picker"
    public static let wheel = "id_workout_picker_wheel"
    public static let confirmButton = "id_workout_picker_confirm"
}
