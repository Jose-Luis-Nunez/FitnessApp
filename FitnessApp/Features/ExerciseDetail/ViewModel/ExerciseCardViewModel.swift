import Foundation

final class ExerciseCardViewModel: ObservableObject {
    @Published var exercise: Exercise

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
}
