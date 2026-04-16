import Foundation
import SwiftData
import FitnessCore
@testable import FitnessStorage
import Factory

@MainActor
enum TestHelpers {
    private static let testSuiteName = "com.fitnessapp.tests"

    static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema([
            WorkoutModel.self,
            ExerciseModel.self,
            AnalyticsEntryModel.self,
            SetProgressModel.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    static func registerInMemoryContainer() {
        Container.shared.reset()
        let container = makeInMemoryContainer()
        Container.shared.modelContainer.register { container }

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "current_workout_id")
        defaults.removeObject(forKey: "default_workout_id")
        defaults.removeObject(forKey: "stored_workouts")
        defaults.removeObject(forKey: "swiftdata_migration_complete")
        defaults.removeObject(forKey: "userId")
    }

    static func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "\(testSuiteName).\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    static func makeTempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FitnessTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func cleanupTempDirectory(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    static func makeExercise(
        name: String = "Bench Press",
        weight: Double = 60,
        reps: Int = 10,
        sets: Int = 3,
        seatSetting: String? = nil,
        noSeats: Bool = false,
        isCompleted: Bool = false,
        category: MuscleCategoryGroup = .chest,
        iconName: String? = nil,
        goal: Double? = nil
    ) -> Exercise {
        let icon = iconName ?? category.defaultIconName
        return Exercise(
            name: name, weight: weight, reps: reps, sets: sets,
            seatSetting: seatSetting, noSeats: noSeats, isCompleted: isCompleted,
            iconName: icon, category: category, goal: goal
        )
    }

    static func makeAnalyticsEntry(
        exerciseId: UUID,
        date: Date = Date(),
        setProgress: [SetProgress] = [
            SetProgress(status: .completedDone, currentReps: 10, weight: 60),
            SetProgress(status: .completedMore, currentReps: 12, weight: 60),
            SetProgress(status: .completedLess, currentReps: 8, weight: 60)
        ]
    ) -> AnalyticsEntry {
        AnalyticsEntry(exerciseId: exerciseId, date: date, setProgress: setProgress)
    }
}
