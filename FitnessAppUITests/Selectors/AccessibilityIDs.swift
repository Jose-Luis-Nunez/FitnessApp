enum TrainingIDs {
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
}

enum MuscleCategoryIDs {
    static let startExercise = "id_button_start_exercise"
}

enum ExerciseIDs {
    static let nameLabel = "id_label_exercise_name"
}
