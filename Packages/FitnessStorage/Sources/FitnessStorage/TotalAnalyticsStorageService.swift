import Foundation
import FitnessCore
import Factory

@MainActor
public final class TotalAnalyticsStorageService: TotalAnalyticsStoring {
    private let analyticsStorage: AnalyticsStoring
    private let exerciseStorage: ExerciseStoring
    private let workoutStorage: WorkoutStoring

    public init(
        analyticsStorage: AnalyticsStoring? = nil,
        exerciseStorage: ExerciseStoring? = nil,
        workoutStorage: WorkoutStoring? = nil
    ) {
        self.analyticsStorage = analyticsStorage ?? Container.shared.analyticsStorage()
        self.exerciseStorage = exerciseStorage ?? Container.shared.exerciseStorage()
        self.workoutStorage = workoutStorage ?? Container.shared.workoutStorage()
    }

    public func loadAnalytics(for exerciseId: UUID) -> [AnalyticsEntry] {
        analyticsStorage.load(for: exerciseId)
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
