import Foundation
import FitnessCore
import FitnessTestSupport
import Testing
@testable import FitnessAnalytics

@Suite("AnalyticsEntryFormState", .tags(.fast))
struct AnalyticsEntryFormStateTests {
    @Test func newBilateralEntryCreatesPairedLogicalSets() {
        let exercise = makeBilateralExercise(sets: 3)

        let state = AnalyticsEntryFormState(
            exercise: exercise,
            existingEntry: nil
        )

        #expect(state.isBilateral)
        #expect(state.logicalSetIndices == [0, 1, 2])
        #expect(state.sets.map(\.side) == [
            .left, .right, .left, .right, .left, .right
        ])
    }

    @Test func editingPreservesResultIdentityAndSideMetadata() {
        let exercise = makeBilateralExercise(sets: 1)
        let leftID = UUID()
        let rightID = UUID()
        let entry = AnalyticsEntry(
            exerciseId: exercise.id,
            date: .now,
            setProgress: [
                SetProgress(
                    id: leftID,
                    status: .completedDone,
                    currentReps: 10,
                    weight: 20,
                    side: .left,
                    logicalSetIndex: 0
                ),
                SetProgress(
                    id: rightID,
                    status: .completedDone,
                    currentReps: 11,
                    weight: 22,
                    side: .right,
                    logicalSetIndex: 0
                )
            ]
        )
        var state = AnalyticsEntryFormState(
            exercise: exercise,
            existingEntry: entry
        )

        state.sets[0].reps = 12
        let result = state.makeEntry(exerciseId: exercise.id, date: entry.date)

        #expect(result.setProgress.map(\.id) == [leftID, rightID])
        #expect(result.setProgress.map(\.side) == [.left, .right])
        #expect(result.setProgress[0].currentReps == 12)
        #expect(result.setProgress[1].weight == 22)
    }

    @Test func addAndDeleteOperateOnCompleteLogicalPairs() {
        let exercise = makeBilateralExercise(sets: 1)
        var state = AnalyticsEntryFormState(
            exercise: exercise,
            existingEntry: nil
        )

        state.appendSet(defaultWeight: 24, defaultReps: 8)
        #expect(state.logicalSetIndices == [0, 1])
        let added = state.sets.filter { $0.logicalSetIndex == 1 }
        #expect(added.map(\.side) == [.left, .right])
        #expect(added.allSatisfy { $0.weight == 24 && $0.reps == 8 })

        state.removeLogicalSet(at: 0)
        #expect(state.logicalSetIndices == [1])
        #expect(state.sets.count == 2)
    }

    private func makeBilateralExercise(sets: Int) -> Exercise {
        FitnessTestSupport.makeExercise(
            name: "Torso",
            weight: 20,
            reps: 12,
            sets: sets,
            category: .back,
            executionMode: .bilateral
        )
    }
}
