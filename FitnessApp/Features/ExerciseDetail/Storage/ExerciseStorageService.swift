import Foundation

protocol ExerciseStoring {
    func load(for group: MuscleCategoryGroup) -> [Exercise]
    func save(_ exercises: [Exercise], for group: MuscleCategoryGroup)
}

final class ExerciseStorageService: ExerciseStoring {
    func load(for group: MuscleCategoryGroup) -> [Exercise] {
        let key = "exercises_\(group.rawValue)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Exercise].self, from: data)
        else {
            return []
        }
        return decoded
    }

    func save(_ exercises: [Exercise], for group: MuscleCategoryGroup) {
        let key = "exercises_\(group.rawValue)"
        guard let data = try? JSONEncoder().encode(exercises) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
