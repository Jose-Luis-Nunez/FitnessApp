final class SessionTrainingCache {
    static let shared = SessionTrainingCache()
    private init() {}
    var activeSetVMs: [MuscleCategoryGroup: ActiveSetViewModel] = [:]
}

