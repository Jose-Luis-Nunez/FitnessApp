import Foundation
import Observation
import FitnessCore

@Observable
@MainActor
public final class ExerciseCardViewModel {
    public var exercise: Exercise {
        didSet {
            guard !exercise.isContentEqual(to: oldValue), !isSyncingFromParent else { return }
            onUpdate(exercise)
        }
    }

    private let onUpdate: (Exercise) -> Void
    private var isSyncingFromParent = false

    public init(exercise: Exercise, onUpdate: @escaping (Exercise) -> Void) {
        self.exercise = exercise
        self.onUpdate = onUpdate
    }

    public func syncExercise(_ updated: Exercise) {
        guard !exercise.isContentEqual(to: updated) else { return }
        isSyncingFromParent = true
        exercise = updated
        isSyncingFromParent = false
    }

    public func updateSeat(_ newSeat: String) {
        exercise.seatSetting = newSeat
        exercise.noSeats = false
        onUpdate(exercise)
    }

    public func updateWeight(_ newWeight: Double) {
        exercise.weight = newWeight
        onUpdate(exercise)
    }

    public func updateSets(_ newSets: Int) {
        exercise.sets = newSets
        onUpdate(exercise)
    }

    public func updateReps(_ newReps: Int) {
        exercise.reps = newReps
        onUpdate(exercise)
    }
}
