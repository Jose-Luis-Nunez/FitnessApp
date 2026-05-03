import Factory
import FitnessCore
import os
import SwiftData

private let containerLogger = Logger(subsystem: "FitnessStorage", category: "ModelContainer")

public extension Container {
    var modelContainer: Factory<ModelContainer> {
        self {
            ModelContainerBootstrap.makeProductionContainer()
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
        self { MainActor.assumeIsolated { ExerciseManagementService() } }.singleton
    }
    var totalAnalyticsStorage: Factory<TotalAnalyticsStoring> {
        self { MainActor.assumeIsolated { TotalAnalyticsStorageService() } }.singleton
    }
    var feedbackStorage: Factory<FeedbackStoring> {
        self { MainActor.assumeIsolated { FeedbackStorageService() } }.singleton
    }

    var deleteWorkoutUseCase: Factory<DeleteWorkoutUseCase> {
        self { MainActor.assumeIsolated { DeleteWorkoutUseCase() } }
    }
    var duplicateWorkoutUseCase: Factory<DuplicateWorkoutUseCase> {
        self { MainActor.assumeIsolated { DuplicateWorkoutUseCase() } }
    }
    var saveFeedbackUseCase: Factory<SaveFeedbackUseCase> {
        self { MainActor.assumeIsolated { SaveFeedbackUseCase() } }
    }
    var loadLatestFeedbackUseCase: Factory<LoadLatestFeedbackUseCase> {
        self { MainActor.assumeIsolated { LoadLatestFeedbackUseCase() } }
    }
}
