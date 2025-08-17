import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct TrainingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var currentSet: Int
        var totalSets: Int
        var reps: Int
        var weight: Double
        var isFinished: Bool
    }

    var id: UUID
}


