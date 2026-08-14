import Foundation
import FitnessCore
import FitnessResources

extension WorkoutType {
    public var localizedName: LocalizedStringResource {
        switch self {
        case .pull: AppText.workoutTypePull
        case .push: AppText.workoutTypePush
        case .leg: AppText.workoutTypeLeg
        case .individual: AppText.workoutTypeIndividual
        case .full: AppText.workoutTypeFull
        }
    }
}
