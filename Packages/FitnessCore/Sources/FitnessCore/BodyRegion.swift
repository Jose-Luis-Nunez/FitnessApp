import Foundation

public enum BodyRegion: String, CaseIterable, Identifiable, Codable, Sendable {
    // Back
    case neckLeft
    case neckRight
    case shoulderLeft
    case shoulderRight
    case upperBack
    case middleBack
    case lowerBack

    // Abs
    case abs
    case obliquesLeft
    case obliquesRight

    // Chest
    case chestLeft
    case chestRight

    // Arm
    case bicepsLeft
    case bicepsRight
    case tricepsLeft
    case tricepsRight
    case forearmLeft
    case forearmRight

    // Hands & wrists (shared between chest/arm)
    case handLeft
    case handRight
    case wristLeft
    case wristRight

    // Legs
    case thighFront
    case thighBack
    case thighInner
    case thighOuter
    case kneeLeft
    case kneeRight
    case calf
    case foot
    case ankle

    public var id: String { rawValue }

    public var category: BodyCategory {
        switch self {
        case .neckLeft, .neckRight, .shoulderLeft, .shoulderRight, .upperBack, .middleBack, .lowerBack:
            return .back
        case .abs, .obliquesLeft, .obliquesRight:
            return .abs
        case .chestLeft, .chestRight:
            return .chest
        case .bicepsLeft, .bicepsRight, .tricepsLeft, .tricepsRight, .forearmLeft, .forearmRight:
            return .arm
        case .handLeft, .handRight, .wristLeft, .wristRight:
            return .arm
        case .thighFront, .thighBack, .thighInner, .thighOuter,
             .kneeLeft, .kneeRight, .calf, .foot, .ankle:
            return .legs
        }
    }

    /// Asset name for the body-region icon. If no asset exists under this name
    /// in the asset catalog, `Image(iconAssetName)` renders an empty
    /// space (the tile border and the label remain visible).
    public var iconAssetName: String {
        switch self {
        case .neckLeft:      return "neck_left"
        case .neckRight:     return "neck_right"
        case .shoulderLeft:  return "shoulder_left"
        case .shoulderRight: return "shoulder_right"
        case .upperBack:     return "upper_back"
        case .middleBack:    return "middle_back"
        case .lowerBack:     return "lower_back"
        case .abs:           return "Abs"
        case .obliquesLeft:  return "obliques_left"
        case .obliquesRight: return "obliques_right"
        case .chestLeft:     return "chest_left"
        case .chestRight:    return "chest_right"
        case .bicepsLeft:    return "biceps_left"
        case .bicepsRight:   return "biceps_right"
        case .tricepsLeft:   return "triceps_left"
        case .tricepsRight:  return "triceps_right"
        case .forearmLeft:   return "forearm_left"
        case .forearmRight:  return "forearm_right"
        case .handLeft:      return "hand_left"
        case .handRight:     return "hand_right"
        case .wristLeft:     return "wrist_left"
        case .wristRight:    return "wrist_right"
        case .thighFront:    return "thigh_front"
        case .thighBack:     return "thigh_back"
        case .thighInner:    return "thigh_inner"
        case .thighOuter:    return "thigh_outer"
        case .kneeLeft:      return "knee_left"
        case .kneeRight:     return "knee_right"
        case .calf:          return "Calf"
        case .foot:          return "Foot"
        case .ankle:         return "Ankle"
        }
    }

    /// Returns all regions that belong to a given body category, preserving
    /// declaration order.
    public static func regions(in category: BodyCategory) -> [BodyRegion] {
        allCases.filter { $0.category == category }
    }
}
