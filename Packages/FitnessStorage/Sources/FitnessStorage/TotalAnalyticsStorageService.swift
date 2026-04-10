import Foundation
import FitnessCore
import Factory

@MainActor
public protocol TotalAnalyticsStoring {
    func loadAllAnalytics() -> [AnalyticsEntry]
    func loadAllAnalytics(for workoutId: UUID?) -> [AnalyticsEntry]
    func loadAllAnalytics(for date: Date) -> [AnalyticsEntry]
    func getAllExercisesWithAnalytics() -> [Exercise]
    func getAllExercisesWithAnalytics(for workoutId: UUID?) -> [Exercise]
}

@MainActor
public final class TotalAnalyticsStorageService: TotalAnalyticsStoring {
    @Injected(\.analyticsStorage) public var analyticsStorage
    @Injected(\.exerciseStorage) private var exerciseStorage
    @Injected(\.workoutStorage) private var workoutStorage

    nonisolated public init() {
    }

    public func loadAllAnalytics() -> [AnalyticsEntry] {
        return loadAllAnalytics(for: nil)
    }

    public func loadAllAnalytics(for workoutId: UUID?) -> [AnalyticsEntry] {
        var allEntries: [AnalyticsEntry] = []

        let targetWorkoutId = workoutId ?? workoutStorage.currentWorkout?.id

        guard let workoutId = targetWorkoutId else {
            return []
        }

        for category in MuscleCategoryGroup.allCases {
            let exercises = exerciseStorage.loadForWorkout(workoutId: workoutId, category: category)

            for exercise in exercises {
                let entries = analyticsStorage.load(for: exercise.id)
                allEntries.append(contentsOf: entries)
            }
        }

        return allEntries.sorted { $0.date > $1.date }
    }

    public func loadAllAnalytics(for date: Date) -> [AnalyticsEntry] {
        let allEntries = loadAllAnalytics()
        let calendar = Calendar.current

        return allEntries.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }

    public func getAllExercisesWithAnalytics() -> [Exercise] {
        return getAllExercisesWithAnalytics(for: nil)
    }

    public func getAllExercisesWithAnalytics(for workoutId: UUID?) -> [Exercise] {
        var exercisesWithAnalytics: [Exercise] = []

        let targetWorkoutId = workoutId ?? workoutStorage.currentWorkout?.id

        guard let workoutId = targetWorkoutId else {
            return []
        }

        for category in MuscleCategoryGroup.allCases {
            let exercises = exerciseStorage.loadForWorkout(workoutId: workoutId, category: category)

            for exercise in exercises {
                let entries = analyticsStorage.load(for: exercise.id)
                if !entries.isEmpty {
                    exercisesWithAnalytics.append(exercise)
                }
            }
        }

        return exercisesWithAnalytics
    }
}
