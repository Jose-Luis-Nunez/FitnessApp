import Foundation

protocol ExerciseStoring {
    func load(for group: MuscleCategoryGroup) -> [Exercise]
    func save(_ exercises: [Exercise], for group: MuscleCategoryGroup)
}

final class ExerciseStorageService: ExerciseStoring {
    private let fileManager = FileManager.default
    private var userId: String {
        let defaults = UserDefaults.standard
        if let storedUserId = defaults.string(forKey: "userId") {
            return storedUserId } else {
                let newUserId = UUID().uuidString
                defaults.set(newUserId, forKey: "userId")
                return newUserId
            }
    }
    
    var hasUserId: Bool {
        userId != nil
    }
    
    private func fileURL(for group: MuscleCategoryGroup) -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("exercises_\(group.rawValue)_\(userId).json")
    }
    
    func load(for group: MuscleCategoryGroup) -> [Exercise] {
        let fileURL = fileURL(for: group)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("No exercises file found at \(fileURL.path)")
            return []
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let exercises = try decoder.decode([Exercise].self, from: data)
            print("Loaded \(exercises.count) exercises from \(fileURL.path)")
            return exercises
        } catch {
            print("Failed to load exercises: \(error)")
            return []
        }
    }
    
    func save(_ exercises: [Exercise], for group: MuscleCategoryGroup) {
        let fileURL = fileURL(for: group)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(exercises)
            try data.write(to: fileURL, options: .atomic)
            print("Exercises saved to \(fileURL.path)")
        } catch {
            print("Failed to save exercises: \(error)")
        }
    }
}
