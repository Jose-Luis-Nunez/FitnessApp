import Factory

public extension Container {
    var trainingCoordinatorCache: Factory<TrainingCoordinatorCaching> {
        self { MainActor.assumeIsolated { TrainingCoordinatorCache() } }.singleton
    }
}
