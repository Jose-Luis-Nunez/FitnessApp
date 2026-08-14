import Testing
@testable import FitnessCore

@Suite("SeatSettings")
struct SeatSettingsTests {

    // MARK: - Decoding

    @Test func decodesNilAndEmptyToNoPositions() {
        #expect(SeatSettings(encoded: nil).positions == [])
        #expect(SeatSettings(encoded: "").positions == [])
        #expect(SeatSettings(encoded: "   ").positions == [])
    }

    @Test func decodesSingleAndMultiplePositions() {
        #expect(SeatSettings(encoded: "3").positions == ["3"])
        #expect(SeatSettings(encoded: "A / B / C / D").positions == ["A", "B", "C", "D"])
    }

    @Test func decodingIsTolerantOfSpacingAndEmptyParts() {
        // No spaces, extra spaces, and stray separators all normalise the same.
        #expect(SeatSettings(encoded: "A/B").positions == ["A", "B"])
        #expect(SeatSettings(encoded: "  A  /  B  ").positions == ["A", "B"])
        #expect(SeatSettings(encoded: "A / / B").positions == ["A", "B"])
        #expect(SeatSettings(encoded: "A /  / ").positions == ["A"])
    }

    // MARK: - Encoding

    @Test func encodesWithPrettySeparatorOrNilWhenEmpty() {
        #expect(SeatSettings(positions: []).encoded == nil)
        #expect(SeatSettings(positions: ["", "  "]).encoded == nil)
        #expect(SeatSettings(positions: ["3"]).encoded == "3")
        #expect(SeatSettings(positions: ["A", "B", "C"]).encoded == "A / B / C")
    }

    @Test func initFromPositionsTrimsAndDropsEmpties() {
        let s = SeatSettings(positions: ["  A ", "", "B", "   "])
        #expect(s.positions == ["A", "B"])
    }

    @Test func policyLimits() {
        #expect(SeatSettings.editableLimit == 4)
    }
}
