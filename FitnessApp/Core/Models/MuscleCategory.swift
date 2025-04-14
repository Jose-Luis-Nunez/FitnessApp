import Foundation

enum MuscleCategory: String, CaseIterable, Identifiable {
    case chest = "Brust"
    case back = "Rücken"
    case shoulders = "Schultern"
    case biceps = "Bizeps"
    case triceps = "Trizeps"
    case legs = "Beine"
    case abs = "Bauch"
    
    var id: String { rawValue }
    
    var imageName: String {
        switch self {
        case .chest: return MuscleCategoryGroup.chest.imageName
        case .back: return MuscleCategoryGroup.back.imageName
        case .shoulders: return "shoulders"
        case .biceps, .triceps: return MuscleCategoryGroup.arms.imageName
        case .legs: return MuscleCategoryGroup.legs.imageName
        case .abs: return MuscleCategoryGroup.abs.imageName
        }
    }
    
    var group: MuscleCategoryGroup {
        switch self {
        case .biceps, .triceps: return .arms
        case .chest: return .chest
        case .back, .shoulders: return .back
        case .legs: return .legs
        case .abs: return .abs
        }
    }
}

enum MuscleCategoryGroup: String, CaseIterable, Identifiable {
    case arms = "Arme"
    case chest = "Brust"
    case back = "Rücken"
    case legs = "Beine"
    case abs = "Bauch"
    
    var id: String { rawValue }
    
    var imageName: String {
        rawValue.lowercased()
    }
    
    var categories: [MuscleCategory] {
        MuscleCategory.allCases.filter { $0.group == self }
    }
} 