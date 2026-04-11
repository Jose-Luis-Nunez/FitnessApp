import Factory

public extension Container {
    var sessionTrainingCache: Factory<SessionTrainingCache> {
        self { MainActor.assumeIsolated { SessionTrainingCache() } }.singleton
    }
    var trainingCoordinatorCache: Factory<TrainingCoordinatorCaching> {
        self { MainActor.assumeIsolated { TrainingCoordinatorCache() } }.singleton
    }
}
