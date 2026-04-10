import Foundation
import FitnessCore

public final class ExerciseStorageService: ExerciseStoring {
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

    public init() {}

    private func fileURL(for group: MuscleCategoryGroup) -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("exercises_\(group.rawValue)_\(userId).json")
    }

    private func workoutFileURL(workoutId: UUID, category: MuscleCategoryGroup) -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("workout_\(workoutId.uuidString)_\(category.rawValue)_\(userId).json")
    }

    public func load(for group: MuscleCategoryGroup) -> [Exercise] {
        let fileURL = fileURL(for: group)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("No exercises file found at \(fileURL.path)")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let exercises = try decoder.decode([Exercise].self, from: data)
            return exercises
        } catch {
            print("Failed to load exercises: \(error)")
            return []
        }
    }

    public func save(_ exercises: [Exercise], for group: MuscleCategoryGroup) {
        let fileURL = fileURL(for: group)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(exercises)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save exercises: \(error)")
        }
    }

    public func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise] {
        let fileURL = workoutFileURL(workoutId: workoutId, category: category)

        if !fileManager.fileExists(atPath: fileURL.path) {
            let workoutService = WorkoutStorageService.shared
            let isFirstWorkout = workoutService.workouts.first?.id == workoutId

            if isFirstWorkout {
                let oldExercises = load(for: category)
                if !oldExercises.isEmpty {
                    print("Migrating \(oldExercises.count) exercises from old format to first workout \(workoutId)")
                    saveForWorkout(oldExercises, workoutId: workoutId, category: category)
                    return oldExercises
                }
            }
            print("No workout exercises file found at \(fileURL.path)")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let exercises = try decoder.decode([Exercise].self, from: data)
            return exercises
        } catch {
            print("Failed to load workout exercises: \(error)")
            return []
        }
    }

    public func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        let fileURL = workoutFileURL(workoutId: workoutId, category: category)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(exercises)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save workout exercises: \(error)")
        }
    }
}
