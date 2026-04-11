import Factory

public extension Container {
    var resetAllExercisesUseCase: Factory<ResetAllExercisesUseCase> {
        self { MainActor.assumeIsolated { ResetAllExercisesUseCase() } }
    }
}
