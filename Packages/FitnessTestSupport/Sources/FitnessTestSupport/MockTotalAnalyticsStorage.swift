import Foundation
import FitnessCore

@MainActor
public final class MockTotalAnalyticsStorage: TotalAnalyticsStoring {
    private let analyticsStorage: MockAnalyticsStorage
    private let exerciseStorage: MockExerciseStorage
    private let workoutStorage: MockWorkoutStorage

    public init(
        analyticsStorage: MockAnalyticsStorage,
        exerciseStorage: MockExerciseStorage,
        workoutStorage: MockWorkoutStorage
    ) {
        self.analyticsStorage = analyticsStorage
        self.exerciseStorage = exerciseStorage
        self.workoutStorage = workoutStorage
    }

    public func loadAnalytics(for exerciseId: UUID) -> [AnalyticsEntry] {
        analyticsStorage.load(for: exerciseId)
    }

    public func loadAllAnalytics() -> [AnalyticsEntry] {
        loadAllAnalytics(for: nil)
    }

    public func loadAllAnalytics(for workoutId: UUID?) -> [AnalyticsEntry] {
        let targetId = workoutId ?? workoutStorage.currentWorkout?.id
        guard let wid = targetId else { return [] }

        var entries: [AnalyticsEntry] = []
        for category in MuscleCategoryGroup.allCases {
            let exercises = exerciseStorage.loadForWorkout(workoutId: wid, category: category)
            for exercise in exercises {
                entries.append(contentsOf: analyticsStorage.load(for: exercise.id))
            }
        }
        return entries.sorted { $0.date > $1.date }
    }

    public func loadAllAnalytics(for date: Date) -> [AnalyticsEntry] {
        let all = loadAllAnalytics()
        let calendar = Calendar.current
        return all.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    public func getAllExercisesWithAnalytics() -> [Exercise] {
        getAllExercisesWithAnalytics(for: nil)
    }

    public func getAllExercisesWithAnalytics(for workoutId: UUID?) -> [Exercise] {
        let targetId = workoutId ?? workoutStorage.currentWorkout?.id
        guard let wid = targetId else { return [] }

        var result: [Exercise] = []
        for category in MuscleCategoryGroup.allCases {
            let exercises = exerciseStorage.loadForWorkout(workoutId: wid, category: category)
            for exercise in exercises {
                if !analyticsStorage.load(for: exercise.id).isEmpty {
                    result.append(exercise)
                }
            }
        }
        return result
    }
}
