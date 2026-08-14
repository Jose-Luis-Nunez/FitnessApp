import Foundation
import FitnessCore
import FitnessTestSupport
import Testing
@testable import FitnessAnalytics

@Suite("AnalyticsEntryFormState", .tags(.fast))
struct AnalyticsEntryFormStateTests {
    @Test func bilateralDraftCreatesAddsAndRemovesCompleteLogicalPairs() {
        let exercise = makeBilateralExercise(sets: 3)
        var state = AnalyticsEntryFormState(
            exercise: exercise,
            existingEntry: nil
        )

        #expect(state.isBilateral)
        #expect(state.logicalSetIndices == [0, 1, 2])
        #expect(state.sets.map(\.side) == [
            .left, .right, .left, .right, .left, .right
        ])

        state.appendSet(defaultWeight: 24, defaultReps: 8)
        #expect(state.logicalSetIndices == [0, 1, 2, 3])
        let added = state.sets.filter { $0.logicalSetIndex == 3 }
        #expect(added.map(\.side) == [.left, .right])
        #expect(added.allSatisfy { $0.weight == 24 && $0.reps == 8 })

        state.removeLogicalSet(at: 0)
        #expect(state.logicalSetIndices == [1, 2, 3])
        #expect(state.sets.count == 6)
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
        var state = AnalyticsEntryFormState(exercise: exercise, existingEntry: entry)

        state.sets[0].reps = 12
        let result = state.makeEntry(exerciseId: exercise.id, date: entry.date)

        #expect(result.setProgress.map(\.id) == [leftID, rightID])
        #expect(result.setProgress.map(\.side) == [.left, .right])
        #expect(result.setProgress[0].currentReps == 12)
        #expect(result.setProgress[1].weight == 22)
    }

    @Test func standardDraftMutationsAndValidationFollowWeightPolicy() {
        let weighted = FitnessTestSupport.makeExercise(weight: 20, reps: 10, sets: 3)
        var state = AnalyticsEntryFormState(exercise: weighted, existingEntry: nil)

        #expect(!state.isBilateral)
        #expect(!state.isSaveDisabled(hasWeight: true))

        state.sets[0].weight = 0
        #expect(state.isSaveDisabled(hasWeight: true))
        #expect(!state.isSaveDisabled(hasWeight: false))

        state.sets[0].weight = 20
        state.sets[0].reps = 0
        #expect(state.isSaveDisabled(hasWeight: true))
        #expect(state.isSaveDisabled(hasWeight: false))

        state.appendSet(defaultWeight: 25, defaultReps: 8)
        #expect(state.sets.count == 2)
        #expect(state.sets[1].weight == 25)
        #expect(state.sets[1].reps == 8)

        state.removePhysicalSet(at: 99)
        #expect(state.sets.count == 2)
        state.removePhysicalSet(at: 0)
        #expect(state.sets.count == 1)
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
