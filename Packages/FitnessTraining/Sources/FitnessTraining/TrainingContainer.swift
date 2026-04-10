import Factory

public extension Container {
    var sessionTrainingCache: Factory<SessionTrainingCache> {
        self { MainActor.assumeIsolated { SessionTrainingCache() } }.singleton
    }
}
