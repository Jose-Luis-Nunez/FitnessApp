import Foundation

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

enum ExerciseCardIDs {
    static func completedCard(_ id: UUID) -> String { "id_card_completed_\(id.uuidString)" }
    static func activeCard(_ id: UUID) -> String { "id_card_active_\(id.uuidString)" }
    static func idleCard(_ id: UUID) -> String { "id_card_idle_\(id.uuidString)" }
    static let completedCardPrefix = "id_card_completed_"
    static let activeCardPrefix = "id_card_active_"
    static let idleCardPrefix = "id_card_idle_"
}
