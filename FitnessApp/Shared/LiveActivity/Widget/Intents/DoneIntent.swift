import AppIntents

struct DoneIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("action.done")

    func perform() async throws -> some IntentResult {
        TrainingLiveActionRouter.post(.done)
        return .result()
    }
}
