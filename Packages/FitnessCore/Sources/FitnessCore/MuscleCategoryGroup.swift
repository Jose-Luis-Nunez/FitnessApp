import Foundation

public enum MuscleCategoryGroup: String, CaseIterable, Identifiable, Codable, Sendable {
    case arms, chest, back, legs, abs

    public var id: String { rawValue }

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
        guard let icon = availableIcons.first else {
            preconditionFailure("\(self) has no availableIcons")
        }
        return icon
    }
}
