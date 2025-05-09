import Foundation

enum SetAction: String, Codable {
    case none, done, less, more
}

struct SetProgress: Codable {
    let action: SetAction
    let currentReps: Int
    let weight: Int
}
