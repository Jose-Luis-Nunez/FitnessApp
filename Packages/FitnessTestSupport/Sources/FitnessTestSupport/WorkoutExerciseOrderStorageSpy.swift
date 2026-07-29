import Foundation
import FitnessCore

@MainActor
public final class WorkoutExerciseOrderStorageSpy: WorkoutExerciseOrderStoring {
    public private(set) var recordedStarts: [(workoutId: UUID, exerciseId: UUID)] = []
    public private(set) var finalizedWorkoutIds: [UUID] = []
    public var onFinalize: ((UUID) -> Void)?

    public init() {}

    public func recordStart(workoutId: UUID, exerciseId: UUID) {
        recordedStarts.append((workoutId, exerciseId))
    }

    public func finalizeCycle(workoutId: UUID) {
        finalizedWorkoutIds.append(workoutId)
        onFinalize?(workoutId)
    }
}
