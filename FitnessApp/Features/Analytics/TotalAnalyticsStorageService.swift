import Foundation

protocol TotalAnalyticsStoring {
    func loadAllAnalytics() -> [AnalyticsEntry]
    func loadAllAnalytics(for workoutId: UUID?) -> [AnalyticsEntry]
    func loadAllAnalytics(for date: Date) -> [AnalyticsEntry]
    func getAllExercisesWithAnalytics() -> [Exercise]
    func getAllExercisesWithAnalytics(for workoutId: UUID?) -> [Exercise]
}

final class TotalAnalyticsStorageService: TotalAnalyticsStoring {
    let analyticsStorage: AnalyticsStorageService
    private let exerciseStorage: ExerciseStorageService
    private let workoutStorage: WorkoutStorageService
    
    init(
        analyticsStorage: AnalyticsStorageService = AnalyticsStorageService(),
        exerciseStorage: ExerciseStorageService = ExerciseStorageService(),
        workoutStorage: WorkoutStorageService = WorkoutStorageService.shared
    ) {
        self.analyticsStorage = analyticsStorage
        self.exerciseStorage = exerciseStorage
        self.workoutStorage = workoutStorage
    }
    
    func loadAllAnalytics() -> [AnalyticsEntry] {
        return loadAllAnalytics(for: nil) // Load for current workout
    }
    
    func loadAllAnalytics(for workoutId: UUID?) -> [AnalyticsEntry] {
        var allEntries: [AnalyticsEntry] = []
        
        // Use current workout if no specific workout ID provided
        let targetWorkoutId = workoutId ?? workoutStorage.currentWorkout?.id
        
        guard let workoutId = targetWorkoutId else {
            return [] // No workout selected
        }
        
        // Only iterate through the specified/current workout
        for category in MuscleCategoryGroup.allCases {
            let exercises = exerciseStorage.loadForWorkout(workoutId: workoutId, category: category)
            
            // For each exercise, load its analytics
            for exercise in exercises {
                let entries = analyticsStorage.load(for: exercise.id)
                allEntries.append(contentsOf: entries)
            }
        }
        
        // Sort by date (newest first)
        return allEntries.sorted { $0.date > $1.date }
    }
    
    func loadAllAnalytics(for date: Date) -> [AnalyticsEntry] {
        let allEntries = loadAllAnalytics()
        let calendar = Calendar.current
        
        return allEntries.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }
    
    func getAllExercisesWithAnalytics() -> [Exercise] {
        return getAllExercisesWithAnalytics(for: nil) // Load for current workout
    }
    
    func getAllExercisesWithAnalytics(for workoutId: UUID?) -> [Exercise] {
        var exercisesWithAnalytics: [Exercise] = []
        
        // Use current workout if no specific workout ID provided
        let targetWorkoutId = workoutId ?? workoutStorage.currentWorkout?.id
        
        guard let workoutId = targetWorkoutId else {
            return [] // No workout selected
        }
        
        // Only iterate through the specified/current workout
        for category in MuscleCategoryGroup.allCases {
            let exercises = exerciseStorage.loadForWorkout(workoutId: workoutId, category: category)
            
            // Filter exercises that have analytics data
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
