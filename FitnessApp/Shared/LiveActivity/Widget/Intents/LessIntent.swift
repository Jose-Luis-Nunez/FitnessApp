import AppIntents

struct LessIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("action.less")

    func perform() async throws -> some IntentResult {
        TrainingLiveActionRouter.post(.less)
        return .result()
    }
}
