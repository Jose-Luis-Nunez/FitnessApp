import Factory
import FitnessCore

public extension Container {
    var workoutStorage: Factory<WorkoutStorageService> {
        self { MainActor.assumeIsolated { WorkoutStorageService() } }.singleton
    }
    var exerciseStorage: Factory<ExerciseStorageService> {
        self { ExerciseStorageService() }.singleton
    }
    var analyticsStorage: Factory<AnalyticsStorageService> {
        self { AnalyticsStorageService() }.singleton
    }
    var exerciseManagement: Factory<ExerciseManagementService> {
        self { ExerciseManagementService() }.singleton
    }
    var totalAnalyticsStorage: Factory<TotalAnalyticsStorageService> {
        self { TotalAnalyticsStorageService() }.singleton
    }
}
