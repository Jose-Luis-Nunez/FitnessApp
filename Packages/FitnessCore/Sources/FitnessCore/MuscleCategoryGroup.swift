import Foundation
import FitnessResources

public enum MuscleCategoryGroup: String, CaseIterable, Identifiable, Codable, Sendable {
    case arms, chest, back, legs, abs

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .arms: return L10n.muscleCategoryOptionArms
        case .chest: return L10n.muscleCategoryOptionChest
        case .back: return L10n.muscleCategoryOptionBack
        case .legs: return L10n.muscleCategoryOptionLegs
        case .abs: return L10n.muscleCategoryOptionAbs
        }
    }

    public var availableIcons: [String] {
        switch self {
        case .arms:  return ["defaultArmsIcon", "bicepsIcon", "tricepsIcon"]
        case .chest: return ["defaultChestIcon", "chestPressIcon", "chestFlyIcon"]
        case .back:  return ["defaultBackIcon", "latPullIcon", "rowIcon"]
        case .legs:  return ["defaultLegsIcon", "squatIcon", "legPressIcon"]
        case .abs:   return ["defaultAbsIcon", "fullAbsIcon", "plankIcon"]
        }
    }

    public var defaultIconName: String {
        availableIcons.first!
    }
}
