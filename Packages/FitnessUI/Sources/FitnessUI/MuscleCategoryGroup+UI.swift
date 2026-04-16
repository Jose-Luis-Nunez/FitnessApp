import SwiftUI
import FitnessCore
import FitnessResources

extension MuscleCategoryGroup {
    public var displayName: String {
        switch self {
        case .arms: return L10n.muscleCategoryOptionArms
        case .chest: return L10n.muscleCategoryOptionChest
        case .back: return L10n.muscleCategoryOptionBack
        case .legs: return L10n.muscleCategoryOptionLegs
        case .abs: return L10n.muscleCategoryOptionAbs
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
