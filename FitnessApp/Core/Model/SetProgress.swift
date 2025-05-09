import Foundation

enum SetAction: String, Codable {
    case none, done, less, more
}

struct SetProgress: Codable, Hashable, Equatable {
    let action: SetAction
    let currentReps: Int
    let weight: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(action)
        hasher.combine(currentReps)
        hasher.combine(weight)
    }
    
    static func ==(lhs: SetProgress, rhs: SetProgress) -> Bool {
        return lhs.action == rhs.action &&
               lhs.currentReps == rhs.currentReps &&
               lhs.weight == rhs.weight
    }
}
