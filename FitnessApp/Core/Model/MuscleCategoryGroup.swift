import SwiftUI
enum MuscleCategoryGroup: String, CaseIterable, Identifiable, Codable {
    case arms, chest, back, legs, abs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arms: return L10n.muscleCategoryOptionArms
        case .chest: return L10n.muscleCategoryOptionChest
        case .back: return L10n.muscleCategoryOptionBack
        case .legs: return L10n.muscleCategoryOptionLegs
        case .abs: return L10n.muscleCategoryOptionAbs
        }
    }

    var availableIcons: [String] {
        switch self {
        case .arms:  return ["defaultArmsIcon", "bicepsIcon", "tricepsIcon"]
        case .chest: return ["defaultChestIcon", "chestPressIcon", "chestFlyIcon"]
        case .back:  return ["defaultBackIcon", "latPullIcon", "rowIcon"]
        case .legs:  return ["defaultLegsIcon", "squatIcon", "legPressIcon"]
        case .abs:   return ["defaultAbsIcon", "fullAbsIcon", "plankIcon"]
        }
    }

    var defaultIconName: String {
        availableIcons.first!
    }
    
    var iconAlignment: Alignment {
        switch self {
        case .legs:
            return .bottom
        default:
            return .top
        }
    }
}
