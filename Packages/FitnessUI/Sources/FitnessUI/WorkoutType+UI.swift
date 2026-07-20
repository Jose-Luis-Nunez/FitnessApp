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
}
