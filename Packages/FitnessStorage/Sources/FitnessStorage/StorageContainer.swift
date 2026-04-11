import Factory
import FitnessCore

public extension Container {
    var workoutStorage: Factory<WorkoutStoring> {
        self { MainActor.assumeIsolated { WorkoutStorageService() } }.singleton
    }
    var exerciseStorage: Factory<ExerciseStorageService> {
        self { ExerciseStorageService() }.singleton
    }
    var analyticsStorage: Factory<AnalyticsStorageService> {
        self { AnalyticsStorageService() }.singleton
    }
    var exerciseManagement: Factory<ExerciseManaging> {
        self { ExerciseManagementService() }.singleton
    }
    var totalAnalyticsStorage: Factory<TotalAnalyticsStorageService> {
        self { TotalAnalyticsStorageService() }.singleton
    }

    var deleteWorkoutUseCase: Factory<DeleteWorkoutUseCase> {
        self { MainActor.assumeIsolated { DeleteWorkoutUseCase() } }
    }
    var duplicateWorkoutUseCase: Factory<DuplicateWorkoutUseCase> {
        self { MainActor.assumeIsolated { DuplicateWorkoutUseCase() } }
    }
}
