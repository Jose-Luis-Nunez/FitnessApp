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
        exercise.noSeats = false
        onUpdate(exercise)
    }

    func updateWeight(_ newWeight: Double) {
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
    
    var displaySeatText: String {
        if let seat = exercise.seatSetting, !seat.isEmpty {
            return seat
        } else {
            return L10n.seatChipDefaultvalue
        }
    }
}
