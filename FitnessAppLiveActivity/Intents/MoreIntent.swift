import AppIntents

@available(iOS 17.0, *)
struct MoreIntent: AppIntent {
    static var title: LocalizedStringResource = "More"

    func perform() async throws -> some IntentResult {
        TrainingLiveActionRouter.post(.more)
        return .result()
    }
}


