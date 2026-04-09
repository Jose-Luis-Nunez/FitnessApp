import AppIntents

struct MoreIntent: AppIntent {
    static var title: LocalizedStringResource = "More"

    func perform() async throws -> some IntentResult {
        TrainingLiveActionRouter.post(.more)
        return .result()
    }
}


