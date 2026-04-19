import Foundation

public enum BodyRegion: String, CaseIterable, Identifiable, Codable, Sendable {
    // Rücken
    case neckLeft
    case neckRight
    case shoulderLeft
    case shoulderRight
    case upperBack
    case middleBack
    case lowerBack

    // Bauch
    case abs
    case obliquesLeft
    case obliquesRight

    // Brust
    case chestLeft
    case chestRight

    // Arm
    case bicepsLeft
    case bicepsRight
    case tricepsLeft
    case tricepsRight
    case forearmLeft
    case forearmRight

    // Hände & Handgelenke (shared zwischen Brust/Arm)
    case handLeft
    case handRight
    case wristLeft
    case wristRight

    // Beine
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

    public var displayName: String {
        switch self {
        case .neckLeft:      return "Neck left"
        case .neckRight:     return "Neck right"
        case .shoulderLeft:  return "Shoulder left"
        case .shoulderRight: return "Shoulder right"
        case .upperBack:     return "Upper back"
        case .middleBack:    return "Middle back"
        case .lowerBack:     return "Lower back"
        case .abs:           return "Abs"
        case .obliquesLeft:  return "Obliques left"
        case .obliquesRight: return "Obliques right"
        case .chestLeft:     return "Chest left"
        case .chestRight:    return "Chest right"
        case .bicepsLeft:    return "Biceps left"
        case .bicepsRight:   return "Biceps right"
        case .tricepsLeft:   return "Triceps left"
        case .tricepsRight:  return "Triceps right"
        case .forearmLeft:   return "Forearm left"
        case .forearmRight:  return "Forearm right"
        case .handLeft:      return "Hand left"
        case .handRight:     return "Hand right"
        case .wristLeft:     return "Wrist left"
        case .wristRight:    return "Wrist right"
        case .thighFront:    return "Thigh front"
        case .thighBack:     return "Thigh back"
        case .thighInner:    return "Thigh inner"
        case .thighOuter:    return "Thigh outer"
        case .kneeLeft:      return "Knee left"
        case .kneeRight:     return "Knee right"
        case .calf:          return "Calf"
        case .foot:          return "Foot"
        case .ankle:         return "Ankle"
        }
    }

    /// Asset-Name für das Body-Region-Icon. Wenn kein Asset unter diesem Namen
    /// im Asset-Catalog existiert, rendert `Image(iconAssetName)` einen leeren
    /// Platz (der Tile-Rahmen und das Label bleiben weiterhin sichtbar).
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
