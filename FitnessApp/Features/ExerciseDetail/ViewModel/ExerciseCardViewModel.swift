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
}
