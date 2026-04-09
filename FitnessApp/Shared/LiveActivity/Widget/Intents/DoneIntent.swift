import AppIntents

struct DoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Done"

    func perform() async throws -> some IntentResult {
        TrainingLiveActionRouter.post(.done)
        return .result()
    }
}


