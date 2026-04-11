import Factory

public extension Container {
    var sessionTrainingCache: Factory<SessionTrainingCache> {
        self { MainActor.assumeIsolated { SessionTrainingCache() } }.singleton
    }
    var trainingCoordinatorCache: Factory<TrainingCoordinatorCaching> {
        self { MainActor.assumeIsolated { TrainingCoordinatorCache() } }.singleton
    }

    var startTrainingUseCase: Factory<StartTrainingUseCase> {
        self { MainActor.assumeIsolated { StartTrainingUseCase() } }
    }
    var completeSetUseCase: Factory<CompleteSetUseCase> {
        self { MainActor.assumeIsolated { CompleteSetUseCase() } }
    }
    var finishExerciseUseCase: Factory<FinishExerciseUseCase> {
        self { MainActor.assumeIsolated { FinishExerciseUseCase() } }
    }
    var cancelTrainingUseCase: Factory<CancelTrainingUseCase> {
        self { MainActor.assumeIsolated { CancelTrainingUseCase() } }
    }
    var resetExerciseUseCase: Factory<ResetExerciseUseCase> {
        self { MainActor.assumeIsolated { ResetExerciseUseCase() } }
    }
}
