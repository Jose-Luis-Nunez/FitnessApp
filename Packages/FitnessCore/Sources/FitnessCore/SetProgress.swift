import Foundation

public enum SetStatus: String, Codable, Sendable {
    case notStarted
    case inProgress
    case completedDone
    case completedLess
    case completedMore
}

public struct SetProgress: Codable, Hashable, Equatable, Sendable {
    public var status: SetStatus
    public var currentReps: Int
    public var weight: Double

    public init(status: SetStatus, currentReps: Int, weight: Double) {
        self.status = status
        self.currentReps = currentReps
        self.weight = weight
    }

    public static func == (lhs: SetProgress, rhs: SetProgress) -> Bool {
        lhs.status == rhs.status &&
        lhs.currentReps == rhs.currentReps &&
        lhs.weight == rhs.weight
    }
}
