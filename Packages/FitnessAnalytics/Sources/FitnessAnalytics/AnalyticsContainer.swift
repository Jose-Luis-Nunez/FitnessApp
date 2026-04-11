import Factory

public extension Container {
    var saveAnalyticsUseCase: Factory<SaveAnalyticsUseCase> {
        self { MainActor.assumeIsolated { SaveAnalyticsUseCase() } }
    }
    var deleteAnalyticsSetUseCase: Factory<DeleteAnalyticsSetUseCase> {
        self { MainActor.assumeIsolated { DeleteAnalyticsSetUseCase() } }
    }
    var saveOrReplaceAnalyticsUseCase: Factory<SaveOrReplaceAnalyticsUseCase> {
        self { MainActor.assumeIsolated { SaveOrReplaceAnalyticsUseCase() } }
    }
}
