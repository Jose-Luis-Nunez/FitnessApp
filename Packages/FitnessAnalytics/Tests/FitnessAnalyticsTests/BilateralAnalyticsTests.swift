import FitnessCore
import Testing
@testable import FitnessAnalytics

@Suite("Bilateral analytics", .tags(.fast))
struct BilateralAnalyticsTests {
    @Test("Complete bilateral entries group left and right by logical set")
    func groupsCompletePairs() throws {
        let progress = makeProgress()

        let groups = try #require(BilateralSetGrouping.groups(for: progress))

        #expect(groups.count == 3)
        #expect(groups.map(\.logicalSetIndex) == [0, 1, 2])
        #expect(groups[1].left.currentReps == 11)
        #expect(groups[1].right.currentReps == 12)
    }

    @Test("Mixed and legacy entries keep flat representation")
    func mixedEntriesDoNotGroup() {
        var progress = makeProgress()
        progress[2].side = nil

        #expect(BilateralSetGrouping.groups(for: progress) == nil)
    }

    @Test("Duplicate sides are ambiguous and keep flat representation")
    func duplicateSidesDoNotGroup() {
        var progress = makeProgress()
        progress[1].side = .left

        #expect(BilateralSetGrouping.groups(for: progress) == nil)
    }

    @Test("Set label uses logical count and per-side suffix")
    func bilateralSetLabelUsesLogicalCount() {
        #expect(
            BilateralSetGrouping.setRepsLabel(forEntries: [makeProgress()], reps: 12)
                == "3×12 / side"
        )
        #expect(
            BilateralSetGrouping.setRepsLabel(
                forEntries: [makeProgress(), makeProgress()],
                reps: 12
            ) == "6×12 / side"
        )
    }

    private func makeProgress() -> [SetProgress] {
        (0..<3).flatMap { logicalIndex in
            [
                SetProgress(
                    status: .completedDone,
                    currentReps: 10 + logicalIndex,
                    weight: 20 + Double(logicalIndex),
                    side: .left,
                    logicalSetIndex: logicalIndex
                ),
                SetProgress(
                    status: .completedMore,
                    currentReps: 11 + logicalIndex,
                    weight: 21 + Double(logicalIndex * 2),
                    side: .right,
                    logicalSetIndex: logicalIndex
                )
            ]
        }
    }
}
