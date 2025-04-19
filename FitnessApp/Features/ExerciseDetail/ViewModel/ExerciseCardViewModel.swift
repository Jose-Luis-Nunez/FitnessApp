import Foundation

final class ExerciseCardViewModel: ObservableObject {
    @Published var exercise: Exercise {
        didSet {
            onUpdate(exercise)
        }
    }
    
    private let onUpdate: (Exercise) -> Void

    init(exercise: Exercise, onUpdate: @escaping (Exercise) -> Void) {
        self.exercise = exercise
        self.onUpdate = onUpdate
    }
    
    func updateSeat(_ newSeat: String) {
        exercise.seatSetting = newSeat
        onUpdate(exercise)
    }

    func updateWeight(_ newWeight: Int) {
        exercise.weight = newWeight
        onUpdate(exercise)
    }

    func updateSets(_ newSets: Int) {
        exercise.sets = newSets
        onUpdate(exercise)
    }

    func updateReps(_ newReps: Int) {
        exercise.reps = newReps
        onUpdate(exercise)
    }
    
    func generateFieldTypes() -> [ExerciseFieldType] {
        [
            .weight(exercise.weight, AppStyle.Dimensions.chipHeight * 2 + 42),
            .sets(exercise.sets, nil),
            .reps(exercise.reps, nil)
        ]
    }
}
