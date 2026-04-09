import AppIntents

struct LessIntent: AppIntent {
    static var title: LocalizedStringResource = "Less"

    func perform() async throws -> some IntentResult {
        TrainingLiveActionRouter.post(.less)
        return .result()
    }
}


