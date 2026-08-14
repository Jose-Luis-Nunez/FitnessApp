import AppIntents

struct MoreIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("action.more")

    func perform() async throws -> some IntentResult {
        TrainingLiveActionRouter.post(.more)
        return .result()
    }
}
