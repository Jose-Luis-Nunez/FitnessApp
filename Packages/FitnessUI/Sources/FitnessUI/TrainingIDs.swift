import Foundation

public enum TrainingIDs {
    public static let doneButton = "id_button_done"
    public static let finishButton = "id_button_finish"
    public static let startButton = "id_button_start"
    public static let allDoneButton = "id_button_all_done"
    public static let quickDoneButton = "id_button_quick_done"
    public static let feedbackButton = "id_button_feedback"
    public static let feedbackSaveButton = "id_button_feedback_save"
    public static let feedbackCancelButton = "id_button_feedback_cancel"
    public static let energyLevelSlider = "id_slider_energy_level"
    public static func symptomChip(_ rawValue: String) -> String { "id_symptom_\(rawValue)" }
    public static func controlButton(_ text: String) -> String { "id_button_\(text.lowercased())" }
    public static func repsField(set index: Int) -> String { "id_reps_set_\(index)" }
    public static func quickDoneSetButton(index: Int) -> String { "id_button_quick_done_set_\(index)" }
}
