import Foundation

// MARK: - Storage Errors
enum StorageError: LocalizedError {
    case saveError(String)
    case loadError(String)
    case notFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .saveError(let message): return "Failed to save data: \(message)"
        case .loadError(let message): return "Failed to load data: \(message)"
        case .notFound: return "Data not found"
        case .invalidData: return "Invalid data format"
        }
    }
}

// MARK: - Generic Storage Protocol
protocol StorageProtocol {
    func save<T: Codable>(_ items: T, forKey key: String) throws
    func load<T: Codable>(forKey key: String) throws -> T
    func remove(forKey key: String) throws
    func exists(forKey key: String) -> Bool
}

// MARK: - Exercise Storage Protocol
protocol ExerciseStoring: AnyObject {
    func save(_ exercises: [Exercise], for group: MuscleCategoryGroup)
    func load(for group: MuscleCategoryGroup) -> [Exercise]
    func clearExercises(for group: MuscleCategoryGroup)
} 
