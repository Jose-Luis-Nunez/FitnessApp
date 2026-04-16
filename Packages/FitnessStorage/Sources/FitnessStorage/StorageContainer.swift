import Factory
import FitnessCore
import SwiftData

public extension Container {
    var modelContainer: Factory<ModelContainer> {
        self {
            let schema = Schema([
                WorkoutModel.self,
                ExerciseModel.self,
                AnalyticsEntryModel.self,
                SetProgressModel.self
            ])
            do {
                return try ModelContainer(for: schema)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }.singleton
    }

    var workoutStorage: Factory<WorkoutStoring> {
        self { MainActor.assumeIsolated {
            WorkoutStorageService(exerciseStorage: Container.shared.exerciseStorage())
        } }.singleton
    }
    var exerciseStorage: Factory<ExerciseStoring> {
        self { MainActor.assumeIsolated { ExerciseStorageService() } }.singleton
    }
    var analyticsStorage: Factory<AnalyticsStoring> {
        self { MainActor.assumeIsolated { AnalyticsStorageService() } }.singleton
    }
    var exerciseManagement: Factory<ExerciseManaging> {
        self { ExerciseManagementService() }.singleton
    }
    var totalAnalyticsStorage: Factory<TotalAnalyticsStoring> {
        self { TotalAnalyticsStorageService() }.singleton
    }

    var deleteWorkoutUseCase: Factory<DeleteWorkoutUseCase> {
        self { MainActor.assumeIsolated { DeleteWorkoutUseCase() } }
    }
    var duplicateWorkoutUseCase: Factory<DuplicateWorkoutUseCase> {
        self { MainActor.assumeIsolated { DuplicateWorkoutUseCase() } }
    }
}
