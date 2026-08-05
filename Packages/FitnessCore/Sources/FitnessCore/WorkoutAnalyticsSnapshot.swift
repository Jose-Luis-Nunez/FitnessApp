import Foundation

/// One consistent workout-wide analytics read. Consumers derive every metric
/// from this value instead of re-entering storage for each exercise or tile.
public struct WorkoutAnalyticsSnapshot: Sendable {
    public let workoutId: UUID
    public let exercises: [Exercise]
    public let entries: [AnalyticsEntry]
    public let entriesByExerciseId: [UUID: [AnalyticsEntry]]

    public init(
        workoutId: UUID,
        exercises: [Exercise],
        entriesByExerciseId: [UUID: [AnalyticsEntry]]
    ) {
        let exerciseIds = exercises.map(\.id)
        let exerciseIdSet = Set(exerciseIds)
        precondition(
            exerciseIdSet.count == exerciseIds.count,
            "Workout analytics snapshots require unique Exercise ids"
        )
        precondition(
            Set(entriesByExerciseId.keys) == exerciseIdSet,
            "Workout analytics snapshots require exactly one history per Exercise id"
        )
        precondition(
            entriesByExerciseId.allSatisfy { exerciseId, entries in
                entries.allSatisfy { $0.exerciseId == exerciseId }
            },
            "Workout analytics histories must match their Exercise id"
        )

        self.workoutId = workoutId
        self.exercises = exercises
        self.entriesByExerciseId = entriesByExerciseId
        self.entries = exercises
            .flatMap { entriesByExerciseId[$0.id] ?? [] }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date > rhs.date }
                if lhs.exerciseId != rhs.exerciseId {
                    return lhs.exerciseId.uuidString < rhs.exerciseId.uuidString
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    public func entries(for exerciseId: UUID) -> [AnalyticsEntry] {
        entriesByExerciseId[exerciseId] ?? []
    }
}
