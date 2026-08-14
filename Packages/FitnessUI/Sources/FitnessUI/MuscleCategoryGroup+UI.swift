import SwiftUI
import FitnessCore
import FitnessResources

extension MuscleCategoryGroup {
    public var localizedName: LocalizedStringResource {
        switch self {
        case .arms: return AppText.muscleArm
        case .chest: return AppText.muscleChest
        case .back: return AppText.muscleBack
        case .legs: return AppText.muscleLegs
        case .abs: return AppText.muscleAbs
        }
    }

    public var localizedGroupName: LocalizedStringResource {
        switch self {
        case .arms: return AppText.muscleArms
        case .chest: return AppText.muscleChest
        case .back: return AppText.muscleBack
        case .legs: return AppText.muscleLegs
        case .abs: return AppText.muscleAbs
        }
    }

    public var iconAlignment: Alignment {
        switch self {
        case .legs:
            return .bottom
        default:
            return .top
        }
    }
}

extension Exercise {
    public var iconAlignment: Alignment {
        category.iconAlignment
    }
}
