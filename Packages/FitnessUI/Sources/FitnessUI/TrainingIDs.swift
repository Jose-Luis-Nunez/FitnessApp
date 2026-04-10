import Foundation

public enum TrainingIDs {
    public static let doneButton = "id_button_done"
    public static let finishButton = "id_button_finish"
    public static let startButton = "id_button_start"
    public static let allDoneButton = "id_button_all_done"
    public static let quickDoneButton = "id_button_quick_done"
    public static func controlButton(_ text: String) -> String { "id_button_\(text.lowercased())" }
    public static func repsField(set index: Int) -> String { "id_reps_set_\(index)" }
    public static func quickDoneSetButton(index: Int) -> String { "id_button_quick_done_set_\(index)" }
}
