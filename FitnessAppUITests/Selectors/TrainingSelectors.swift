enum TrainingSelectors {
    static let doneButton = "id_button_done"
    static let finishButton = "id_button_finish"

    static func repsField(set index: Int) -> String {
        "id_reps_set_\(index)"
    }
}
