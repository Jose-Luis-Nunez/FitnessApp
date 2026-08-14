import Foundation
import Testing
@testable import FitnessCore

@Suite("CardVariant")
struct CardVariantTests {
    @Test func resolverTruthTable() {
        let exerciseID = UUID()
        let otherID = UUID()
        let cases: [(
            name: String,
            completed: Bool,
            visible: Bool,
            activeID: UUID?,
            expected: CardVariant
        )] = [
            ("completed visible match", true, true, exerciseID, .completed),
            ("completed visible mismatch", true, true, otherID, .completed),
            ("completed visible nil", true, true, nil, .completed),
            ("completed hidden match", true, false, exerciseID, .completed),
            ("completed hidden mismatch", true, false, otherID, .completed),
            ("completed hidden nil", true, false, nil, .completed),
            ("incomplete visible match", false, true, exerciseID, .active),
            ("incomplete visible mismatch", false, true, otherID, .idle),
            ("incomplete visible nil", false, true, nil, .idle),
            ("incomplete hidden match", false, false, exerciseID, .idle),
            ("incomplete hidden mismatch", false, false, otherID, .idle),
            ("incomplete hidden nil", false, false, nil, .idle),
        ]

        for testCase in cases {
            #expect(
                resolveCardVariant(
                    isCompleted: testCase.completed,
                    isActiveSetVisible: testCase.visible,
                    activeExerciseId: testCase.activeID,
                    exerciseId: exerciseID
                ) == testCase.expected,
                "Case: \(testCase.name)"
            )
        }
    }
}
