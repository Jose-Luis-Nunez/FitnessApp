import Testing
import Foundation
import FitnessCore
import Mockable
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("LoadFriendComparisonUseCase", .tags(.integration))
@MainActor
struct LoadFriendComparisonUseCaseTests {

    private func makeEnvelope(exercises: [Exercise], analytics: [AnalyticsEntry] = []) -> WorkoutShareEnvelope {
        WorkoutShareEnvelope(
            exportedAt: Date(),
            app: "FitnessApp",
            workout: Workout(name: "Friend WO"),
            exercises: exercises,
            analytics: analytics
        )
    }

    private func makeSUT(
        envelope: WorkoutShareEnvelope? = nil,
        loadEnvelopeError: Error? = nil,
        myExercisesByCategory: [MuscleCategoryGroup: [Exercise]] = [:],
        myAnalytics: [AnalyticsEntry] = []
    ) -> LoadFriendComparisonUseCase {
        let friendMock = MockFriendStoring()
        if let loadEnvelopeError {
            given(friendMock).loadEnvelope(for: .any).willThrow(loadEnvelopeError)
        } else {
            given(friendMock).loadEnvelope(for: .any).willReturn(envelope ?? makeEnvelope(exercises: []))
        }

        let exerciseMock = MockExerciseStoring(policy: .relaxedVoid)
        // Specific category matchers first; the `.any` catch-all must be
        // registered LAST so it only acts as the fallback (Mockable precedence).
        for (category, exercises) in myExercisesByCategory {
            given(exerciseMock).loadForWorkout(workoutId: .any, category: .value(category)).willReturn(exercises)
        }
        given(exerciseMock).loadForWorkout(workoutId: .any, category: .any).willReturn([])

        let analyticsMock = MockTotalAnalyticsStoring(policy: .relaxedVoid)
        // Disambiguate the `for:` overload (UUID? vs Date) with a typed matcher.
        given(analyticsMock).loadAllAnalytics(for: Parameter<UUID?>.any).willReturn(myAnalytics)

        return LoadFriendComparisonUseCase(
            friendStorage: friendMock,
            exerciseStorage: exerciseMock,
            totalAnalyticsStorage: analyticsMock
        )
    }

    private func friend() -> Friend {
        Friend(id: UUID(), name: "Alice", addedAt: Date(), workoutName: "Friend WO")
    }

    @Test("Computes totals and matched pairs across both sides")
    func computesComparison() throws {
        let friendExercises = [
            TestHelpers.makeExercise(name: "Bench Press", weight: 100, reps: 5, category: .chest),
            TestHelpers.makeExercise(name: "Fly", weight: 20, reps: 12, category: .chest)
        ]
        let myExercises = [
            TestHelpers.makeExercise(name: "Bench Press", weight: 80, reps: 8, category: .chest)
        ]
        let sut = makeSUT(
            envelope: makeEnvelope(exercises: friendExercises),
            myExercisesByCategory: [.chest: myExercises]
        )

        let comparison = try sut.execute(friend: friend(), myWorkout: Workout(name: "Mine"))

        #expect(comparison.myMetrics.totalExercises == 1)
        #expect(comparison.friendMetrics.totalExercises == 2)

        let chest = try #require(comparison.categoryComparisons.first { $0.category == .chest })
        #expect(chest.matchedPairs.count == 1, "Bench Press matches by name")
        let pair = try #require(chest.matchedPairs.first)
        #expect(pair.name == "Bench Press")
        #expect(pair.myWeight == 80)
        #expect(pair.friendWeight == 100)
        #expect(chest.friendExclusiveCount == 1, "Fly has no match on my side")
    }

    @Test("Empty friend workout yields zero totals, no crash")
    func handlesEmptyEnvelope() throws {
        let sut = makeSUT(envelope: makeEnvelope(exercises: []))

        let comparison = try sut.execute(friend: friend(), myWorkout: Workout(name: "Mine"))

        #expect(comparison.friendMetrics.totalExercises == 0)
        #expect(comparison.myMetrics.totalExercises == 0)
        #expect(comparison.categoryComparisons.allSatisfy { $0.matchedPairs.isEmpty })
    }

    @Test("Propagates loadEnvelope failure")
    func propagatesEnvelopeError() {
        let sut = makeSUT(loadEnvelopeError: WorkoutShareError.invalidJSON)

        #expect(throws: WorkoutShareError.invalidJSON) {
            try sut.execute(friend: friend(), myWorkout: Workout(name: "Mine"))
        }
    }
}
