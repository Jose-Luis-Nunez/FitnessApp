import SwiftUI
import FitnessCore

extension WorkoutType {
    public var displayName: String {
        switch self {
        case .pull: "Pull"
        case .push: "Push"
        case .leg: "Leg"
        case .individual: "Individual"
        case .full: "Full"
        }
    }

    /// The generic workout body is cropped from the top for every workout
    /// type except legs, whose highlighted area sits in the lower half.
    public var iconAlignment: Alignment {
        self == .leg ? .bottom : .top
    }
}
