import Testing
import Foundation
@testable import FitnessCore

@Suite("ExerciseFeedback")
struct ExerciseFeedbackTests {

    @Test func contentDetectionCoversEveryIndependentField() {
        let exerciseId = UUID()
        let cases: [(name: String, feedback: ExerciseFeedback, expected: Bool)] = [
            ("empty", ExerciseFeedback(exerciseId: exerciseId), false),
            ("energy", ExerciseFeedback(exerciseId: exerciseId, energyLevel: 3), true),
            ("category", ExerciseFeedback(exerciseId: exerciseId, painCategory: .back), true),
            ("regions", ExerciseFeedback(exerciseId: exerciseId, painRegions: [.lowerBack]), true),
            ("symptoms", ExerciseFeedback(exerciseId: exerciseId, symptoms: [.pain]), true),
            ("note", ExerciseFeedback(exerciseId: exerciseId, note: "Unstable shoulder"), true),
            ("empty note", ExerciseFeedback(exerciseId: exerciseId, note: ""), false),
            ("empty regions", ExerciseFeedback(exerciseId: exerciseId, painRegions: []), false),
        ]

        for testCase in cases {
            #expect(
                testCase.feedback.hasAnyContent == testCase.expected,
                "Case: \(testCase.name)"
            )
        }
    }
}
