import Foundation
import SwiftUI

struct Exercise: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var weight: Double
    var reps: Int
    var sets: Int
    var seatSetting: String?
    var isCompleted: Bool
    var iconName: String
    var category: MuscleCategoryGroup
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        weight = try container.decode(Double.self, forKey: .weight)
        reps = try container.decode(Int.self, forKey: .reps)
        sets = try container.decode(Int.self, forKey: .sets)
        seatSetting = try container.decodeIfPresent(String.self, forKey: .seatSetting)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        
        if let icon = try container.decodeIfPresent(String.self, forKey: .iconName) {
            iconName = icon
        } else {
            iconName = "defaultArmsIcon"
        }
        
        if let cat = try container.decodeIfPresent(MuscleCategoryGroup.self, forKey: .category) {
            category = cat
        } else {
            category = .arms
        }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        weight: Double,
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
        lhs.id == rhs.id
    }
}

extension Exercise {
    var displayIconName: String {
        category.availableIcons.contains(iconName)
        ? iconName
        : category.defaultIconName
    }
    
    var iconAlignment: Alignment {
        switch category {
        case .legs:
            return .bottom
        default:
            return .top
        }
    }
}
