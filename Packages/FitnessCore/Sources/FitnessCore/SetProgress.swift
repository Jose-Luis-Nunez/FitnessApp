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

    public init(id: UUID = UUID(), status: SetStatus, currentReps: Int, weight: Double) {
        self.id = id
        self.status = status
        self.currentReps = currentReps
        self.weight = weight
    }

    public static func == (lhs: SetProgress, rhs: SetProgress) -> Bool {
        lhs.status == rhs.status &&
        lhs.currentReps == rhs.currentReps &&
        lhs.weight == rhs.weight
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(status)
        hasher.combine(currentReps)
        hasher.combine(weight)
    }
}
