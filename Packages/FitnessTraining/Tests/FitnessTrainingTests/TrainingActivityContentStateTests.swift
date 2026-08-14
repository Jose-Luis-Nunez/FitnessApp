import Foundation
import Testing
import FitnessResources
@testable import FitnessTraining

@Suite("Training activity localization", .tags(.fast))
struct TrainingActivityContentStateTests {
    struct LanguageFixture: Sendable {
        let code: String?
        let less: String
        let done: String
        let more: String
        let set: String
        let training: String
    }

    @Test("Older content states decode with the English fallback")
    func contentStateWithoutLanguageCodeDecodesInEnglish() throws {
        let data = Data(
            #"{"exerciseName":"Bench Press","currentSet":1,"totalSets":3,"reps":8,"weight":60,"isFinished":false}"#
                .utf8
        )

        let state = try JSONDecoder().decode(
            TrainingActivityContentState.self,
            from: data
        )

        #expect(state.languageCode == nil)
        #expect(state.language == .english)
    }

    @Test(
        "Content state resolves localized widget text",
        arguments: [
            LanguageFixture(
                code: "en",
                less: "Less",
                done: "Done",
                more: "More",
                set: "Set",
                training: "Training"
            ),
            LanguageFixture(
                code: "de",
                less: "Weniger",
                done: "Fertig",
                more: "Mehr",
                set: "Satz",
                training: "Training"
            ),
            LanguageFixture(
                code: nil,
                less: "Less",
                done: "Done",
                more: "More",
                set: "Set",
                training: "Training"
            ),
            LanguageFixture(
                code: "fr",
                less: "Less",
                done: "Done",
                more: "More",
                set: "Set",
                training: "Training"
            ),
        ]
    )
    func contentStateResolvesLocalizedWidgetText(_ fixture: LanguageFixture) {
        let state = TrainingActivityContentState(
            exerciseName: "Bench Press",
            currentSet: 1,
            totalSets: 3,
            reps: 8,
            weight: 60,
            isFinished: false,
            languageCode: fixture.code
        )

        #expect(state.localized(AppText.actionLess) == fixture.less)
        #expect(state.localized(AppText.actionDone) == fixture.done)
        #expect(state.localized(AppText.actionMore) == fixture.more)
        #expect(state.localized(AppText.liveActivitySet) == fixture.set)
        #expect(state.localized(AppText.liveActivityTraining) == fixture.training)
    }
}
