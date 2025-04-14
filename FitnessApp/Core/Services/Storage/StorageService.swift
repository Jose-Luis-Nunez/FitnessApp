import Foundation

// MARK: - Generic Storage Service
final class StorageService: StorageProtocol {
    // MARK: - Properties
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - StorageProtocol Implementation
    func save<T: Codable>(_ items: T, forKey key: String) throws {
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: key)
        } catch {
            throw StorageError.saveError(error.localizedDescription)
        }
    }
    
    func load<T: Codable>(forKey key: String) throws -> T {
        guard let data = userDefaults.data(forKey: key) else {
            throw StorageError.notFound
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw StorageError.loadError(error.localizedDescription)
        }
    }
    
    func remove(forKey key: String) throws {
        userDefaults.removeObject(forKey: key)
    }
    
    func exists(forKey key: String) -> Bool {
        userDefaults.object(forKey: key) != nil
    }
}

// MARK: - Exercise Storage Service
final class ExerciseStorageService: ExerciseStoring {
    // MARK: - Properties
    private let storage: StorageProtocol
    private let errorHandler: ErrorHandler
    
    // MARK: - Initialization
    init(
        storage: StorageProtocol = StorageService(),
        errorHandler: ErrorHandler = .shared
    ) {
        self.storage = storage
        self.errorHandler = errorHandler
    }
    
    // MARK: - ExerciseStoring Implementation
    func save(_ exercises: [Exercise], for group: MuscleCategoryGroup) {
        print("Saving \(exercises.count) exercises for group: \(group.rawValue)")
        Result {
            try storage.save(exercises, forKey: storageKey(for: group))
            print("Successfully saved exercises for group: \(group.rawValue)")
        }
        .handle(errorHandler) { error in
            print("Error saving exercises: \(error.localizedDescription)")
            return AppError.storage(error as? StorageError ?? .saveError(error.localizedDescription))
        }
    }
    
    func load(for group: MuscleCategoryGroup) -> [Exercise] {
        print("Loading exercises for group: \(group.rawValue)")
        do {
            let exercises: [Exercise] = try storage.load(forKey: storageKey(for: group))
            print("Successfully loaded \(exercises.count) exercises for group: \(group.rawValue)")
            return exercises
        } catch StorageError.notFound {
            print("No exercises found for group: \(group.rawValue)")
            return []
        } catch {
            print("Error loading exercises: \(error.localizedDescription)")
            errorHandler.handle(.storage(error as? StorageError ?? .loadError(error.localizedDescription)))
            return []
        }
    }
    
    func clearExercises(for group: MuscleCategoryGroup) {
        print("Clearing exercises for group: \(group.rawValue)")
        Result {
            try storage.remove(forKey: storageKey(for: group))
            print("Successfully cleared exercises for group: \(group.rawValue)")
        }
        .handle(errorHandler) { error in
            print("Error clearing exercises: \(error.localizedDescription)")
            return AppError.storage(error as? StorageError ?? .saveError(error.localizedDescription))
        }
    }
    
    // MARK: - Private Helpers
    private func storageKey(for group: MuscleCategoryGroup) -> String {
        "exercises_\(group.id)"
    }
} 
