import Foundation

enum SetStatus: String, Codable {
    case notStarted
    case inProgress
    case completedDone
    case completedLess
    case completedMore
}

struct SetProgress: Codable, Hashable, Equatable {
    var status: SetStatus
    var currentReps: Int
    var weight: Double

    static func == (lhs: SetProgress, rhs: SetProgress) -> Bool {
        lhs.status == rhs.status &&
        lhs.currentReps == rhs.currentReps &&
        lhs.weight == rhs.weight
    }
}
