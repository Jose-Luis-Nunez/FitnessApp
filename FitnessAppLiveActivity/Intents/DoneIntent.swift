import AppIntents

@available(iOS 17.0, *)
struct DoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Done"

    func perform() async throws -> some IntentResult {
        TrainingLiveActionRouter.post(.done)
        return .result()
    }
}


