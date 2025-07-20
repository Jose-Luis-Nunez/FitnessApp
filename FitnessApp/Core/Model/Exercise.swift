import Foundation

struct Exercise: Identifiable, Codable,Equatable {
    let id: UUID
    var name: String
    var weight: Int
    var reps: Int
    var sets: Int
    var seatSetting: String?
    var isCompleted: Bool
    var iconName: String
    var category: MuscleCategoryGroup

    init(
        id: UUID = UUID(),
        name: String,
        weight: Int,
        reps: Int,
        sets: Int,
        seatSetting: String? = nil,
        isCompleted: Bool = false,
        iconName: String,
        category: MuscleCategoryGroup
    ) {
        self.id = id
        self.name = name
        self.weight = weight
        self.reps = reps
        self.sets = sets
        self.seatSetting = seatSetting
        self.isCompleted = isCompleted
        self.iconName = iconName
        self.category = category
    }
    
    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Exercise {
    var displayIconName: String {
        if category.availableIcons.contains(iconName) {
            return iconName
        } else {
            return category.defaultIconName
        }
    }
}
