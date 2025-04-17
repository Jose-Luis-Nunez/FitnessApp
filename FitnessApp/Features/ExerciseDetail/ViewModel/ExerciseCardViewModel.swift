import Foundation

final class ExerciseCardViewModel: ObservableObject {
    @Published var exercise: Exercise
    @Published var currentSet: Int = 0
    @Published var isSetInProgress = false
    @Published var isCompleted = false
    private let onUpdate: (Exercise) -> Void

    init(exercise: Exercise, onUpdate: @escaping (Exercise) -> Void) {
        self.exercise = exercise
        self.onUpdate = onUpdate
    }

    var startButtonTitle: String {
        if isCompleted {
            return "Start"
        }
        if currentSet == 0 {
            return "Start Sets"
        }
        return "Set \(currentSet + 1) Start"
    }

    var canStartNewSet: Bool {
        return !isCompleted && currentSet < exercise.sets
    }

    func startSet() {
        isSetInProgress = true
    }

    func completeSet() {
        isSetInProgress = false
        currentSet += 1
        if currentSet >= exercise.sets {
            completeExercise()
        }
    }

    private func completeExercise() {
        isCompleted = true
        exercise.isCompleted = true
        onUpdate(exercise)
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
