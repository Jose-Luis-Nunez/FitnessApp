import Foundation

enum MuscleCategoryGroup: String, CaseIterable, Identifiable {
    case arms = "Arme"
    case chest = "Brust"
    case back = "Rücken"
    case legs = "Beine"
    case abs = "Bauch"

    var id: String { rawValue }

    var imageName: String {
        switch self {
        case .arms: return "arms"
        case .chest: return "chest"
        case .back: return "back"
        case .legs: return "legs"
        case .abs: return "abs"
        }
    }
}
