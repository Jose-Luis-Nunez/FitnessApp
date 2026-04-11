import Foundation

public struct Workout: Identifiable, Codable, Hashable, Equatable {
    public let id: UUID
    public var name: String
    public var createdDate: Date
    public var lastModified: Date
    public var selectedCategories: Set<MuscleCategoryGroup>

    public init(name: String, selectedCategories: Set<MuscleCategoryGroup> = Set(MuscleCategoryGroup.allCases)) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.selectedCategories = selectedCategories
    }

    public init(id: UUID, name: String, createdDate: Date, lastModified: Date, selectedCategories: Set<MuscleCategoryGroup> = Set(MuscleCategoryGroup.allCases)) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.lastModified = lastModified
        self.selectedCategories = selectedCategories
    }

    public mutating func updateLastModified() {
        self.lastModified = Date()
    }

    enum CodingKeys: CodingKey {
        case id, name, createdDate, lastModified, selectedCategories
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        lastModified = try container.decode(Date.self, forKey: .lastModified)

        if let categories = try? container.decode(Set<MuscleCategoryGroup>.self, forKey: .selectedCategories) {
            selectedCategories = categories
        } else {
            selectedCategories = Set(MuscleCategoryGroup.allCases)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(selectedCategories, forKey: .selectedCategories)
    }
}

extension Workout {
    public static func == (lhs: Workout, rhs: Workout) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Workout {
    public func copy(withName newName: String? = nil) -> Workout {
        return Workout(
            id: UUID(),
            name: newName ?? "\(self.name) Copy",
            createdDate: Date(),
            lastModified: Date(),
            selectedCategories: self.selectedCategories
        )
    }
}
