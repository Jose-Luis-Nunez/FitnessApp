import Foundation

public struct Exercise: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var weight: Double
    public var reps: Int
    public var sets: Int
    public var seatSetting: String?
    public var noSeats: Bool
    public var isCompleted: Bool
    public var iconName: String
    public var category: MuscleCategoryGroup
    public var goal: Double?
    /// Whether the exercise counts toward progress and is shown by default.
    /// Deactivated exercises (`false`) keep their data + history but drop out of
    /// the `"X of Y"` counts and the lists until reactivated.
    public var isActive: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        weight = try container.decode(Double.self, forKey: .weight)
        reps = try container.decode(Int.self, forKey: .reps)
        sets = try container.decode(Int.self, forKey: .sets)
        seatSetting = try container.decodeIfPresent(String.self, forKey: .seatSetting)
        noSeats = try container.decodeIfPresent(Bool.self, forKey: .noSeats) ?? false
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        goal = try container.decodeIfPresent(Double.self, forKey: .goal)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true

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

    public init(
        id: UUID = UUID(),
        name: String,
        weight: Double,
        reps: Int,
        sets: Int,
        seatSetting: String? = nil,
        noSeats: Bool = false,
        isCompleted: Bool = false,
        iconName: String,
        category: MuscleCategoryGroup,
        goal: Double? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.weight = weight
        self.reps = reps
        self.sets = sets
        self.seatSetting = seatSetting
        self.noSeats = noSeats
        self.isCompleted = isCompleted
        self.iconName = iconName
        self.category = category
        self.goal = goal
        self.isActive = isActive
    }

    public static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Exercise {
    public var hasWeight: Bool { weight > 0 }

    public var displayIconName: String {
        category.availableIcons.contains(iconName)
        ? iconName
        : category.defaultIconName
    }

    /// Whether the seat-edit affordance should be offered (the exercise has a seat).
    public var allowsSeatEditing: Bool { !noSeats }
}
