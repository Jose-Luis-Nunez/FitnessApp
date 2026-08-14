import Foundation

public enum BodyCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case back
    case abs
    case chest
    case arm
    case legs

    public var id: String { rawValue }

}

public extension BodyCategory {
    /// Maps a MuscleCategoryGroup (exercise taxonomy) to the feedback body-category
    /// used to scope the region options shown in the pain region picker.
    static func from(muscleGroup: MuscleCategoryGroup) -> BodyCategory {
        switch muscleGroup {
        case .arms:  return .arm
        case .chest: return .chest
        case .back:  return .back
        case .legs:  return .legs
        case .abs:   return .abs
        }
    }
}
