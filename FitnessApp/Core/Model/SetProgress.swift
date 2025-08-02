import Foundation

enum SetAction: String, Codable {
    case done, less, more
}

enum SetStatus: String, Codable {
    case notStarted
    case inProgress
    case completedDone
    case completedLess
    case completedMore

    var isCompleted: Bool {
        switch self {
        case .completedDone, .completedLess, .completedMore:
            return true
        default:
            return false
        }
    }

    var action: SetAction? {
        switch self {
        case .completedDone: return .done
        case .completedLess: return .less
        case .completedMore: return .more
        default: return nil
        }
    }
}

struct SetProgress: Codable, Hashable, Equatable {
    var status: SetStatus
    var currentReps: Int
    var weight: Double

    static let notStarted = SetProgress(
        status: .notStarted,
        currentReps: 0,
        weight: 0.0
    )

    func isCompleted(with expectedAction: SetAction) -> Bool {
        status.action == expectedAction
    }

    static func == (lhs: SetProgress, rhs: SetProgress) -> Bool {
        lhs.status == rhs.status &&
        lhs.currentReps == rhs.currentReps &&
        lhs.weight == rhs.weight
    }
}
