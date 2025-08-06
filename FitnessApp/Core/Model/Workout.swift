import Foundation

struct Workout: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdDate: Date
    var lastModified: Date
    var exerciseData: [String: Any] // Stores exercise-specific data for each muscle category
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModified = Date()
        self.exerciseData = [:]
    }
    
    init(id: UUID, name: String, createdDate: Date, lastModified: Date, exerciseData: [String: Any] = [:]) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.lastModified = lastModified
        self.exerciseData = exerciseData
    }
    
    mutating func updateLastModified() {
        self.lastModified = Date()
    }
    
    // Custom Codable implementation to handle [String: Any]
    enum CodingKeys: CodingKey {
        case id, name, createdDate, lastModified, exerciseData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        
        // Handle exerciseData as Data and convert back
        if let data = try? container.decode(Data.self, forKey: .exerciseData),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            exerciseData = dict
        } else {
            exerciseData = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(lastModified, forKey: .lastModified)
        
        // Convert exerciseData to Data for encoding
        if let data = try? JSONSerialization.data(withJSONObject: exerciseData) {
            try container.encode(data, forKey: .exerciseData)
        }
    }
}

extension Workout {
    func copy(withName newName: String? = nil) -> Workout {
        return Workout(
            id: UUID(),
            name: newName ?? "\(self.name) Copy",
            createdDate: Date(),
            lastModified: Date(),
            exerciseData: self.exerciseData
        )
    }
} 