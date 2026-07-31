import Foundation

public enum SetStatus: String, Codable, Sendable {
    case notStarted
    case inProgress
    case completedDone
    case completedLess
    case completedMore
}

public struct SetProgress: Identifiable, Codable, Hashable, Equatable, Sendable {
    public let id: UUID
    public var status: SetStatus
    public var currentReps: Int
    public var weight: Double
    public var side: ExerciseSide?
    public var logicalSetIndex: Int?

    public init(
        id: UUID = UUID(),
        status: SetStatus,
        currentReps: Int,
        weight: Double,
        side: ExerciseSide? = nil,
        logicalSetIndex: Int? = nil
    ) {
        self.id = id
        self.status = status
        self.currentReps = currentReps
        self.weight = weight
        self.side = side
        self.logicalSetIndex = logicalSetIndex
    }

    /// Returns an updated result while preserving the execution identity and
    /// bilateral metadata of the original training step.
    public func transitioned(
        to status: SetStatus,
        currentReps: Int,
        weight: Double
    ) -> SetProgress {
        SetProgress(
            id: id,
            status: status,
            currentReps: currentReps,
            weight: weight,
            side: side,
            logicalSetIndex: logicalSetIndex
        )
    }

    public static func == (lhs: SetProgress, rhs: SetProgress) -> Bool {
        lhs.status == rhs.status &&
        lhs.currentReps == rhs.currentReps &&
        lhs.weight == rhs.weight &&
        lhs.side == rhs.side &&
        lhs.logicalSetIndex == rhs.logicalSetIndex
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(status)
        hasher.combine(currentReps)
        hasher.combine(weight)
        hasher.combine(side)
        hasher.combine(logicalSetIndex)
    }
}
