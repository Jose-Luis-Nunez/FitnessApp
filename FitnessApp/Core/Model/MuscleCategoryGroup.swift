enum MuscleCategoryGroup: String, CaseIterable, Identifiable {
    case arms
    case chest
    case back
    case legs
    case abs

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
}
