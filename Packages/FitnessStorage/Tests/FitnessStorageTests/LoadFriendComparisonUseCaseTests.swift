import Testing
import Foundation
import FitnessCore
import FitnessTestSupport
@testable import FitnessStorageTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

@MainActor
private final class FriendStorageStub: FriendStoring {
    var friends: [Friend] = []
    var envelope: WorkoutShareEnvelope?
    var loadError: Error?

    func upsertFriend(name: String, envelopeJSON: String, workoutName: String) throws -> Friend {
        Friend(id: UUID(), name: name, addedAt: .now, workoutName: workoutName)
    }

    func deleteFriend(id: UUID) {}

    func loadEnvelope(for friendId: UUID) throws -> WorkoutShareEnvelope {
        if let loadError { throw loadError }
        return try #require(envelope)
    }
}

@MainActor
private final class TotalAnalyticsStorageStub: TotalAnalyticsStoring {
    var entries: [AnalyticsEntry] = []

    func loadSnapshot(for workoutId: UUID) throws -> WorkoutAnalyticsSnapshot {
        WorkoutAnalyticsSnapshot(workoutId: workoutId, exercises: [], entriesByExerciseId: [:])
    }

    func loadAllAnalytics() -> [AnalyticsEntry] { entries }
    func loadAllAnalytics(for workoutId: UUID?) -> [AnalyticsEntry] { entries }
    func loadAllAnalytics(for date: Date) -> [AnalyticsEntry] { entries }
    func getAllExercisesWithAnalytics() -> [Exercise] { [] }
    func getAllExercisesWithAnalytics(for workoutId: UUID?) -> [Exercise] { [] }
    func loadAnalytics(for exerciseId: UUID) -> [AnalyticsEntry] { [] }
}

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
        let friendMock = FriendStorageStub()
        friendMock.envelope = envelope ?? makeEnvelope(exercises: [])
        friendMock.loadError = loadEnvelopeError

        let exerciseMock = MockExerciseStorage()
        exerciseMock.exercisesByCategory = myExercisesByCategory

        let analyticsMock = TotalAnalyticsStorageStub()
        analyticsMock.entries = myAnalytics

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
