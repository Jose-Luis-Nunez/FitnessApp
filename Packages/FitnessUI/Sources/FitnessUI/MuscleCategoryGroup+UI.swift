import SwiftUI
import FitnessCore

extension MuscleCategoryGroup {
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
