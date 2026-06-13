import Foundation
import FitnessCore
import Factory

/// Builds a `FriendComparison` by decoding the friend's envelope, loading the
/// current user's exercises and analytics for the given workout, and delegating
/// metric computation to `FriendMetricsCalculator`.
@MainActor
public struct LoadFriendComparisonUseCase {
    private let friendStorage: FriendStoring
    private let exerciseStorage: ExerciseStoring
    private let totalAnalyticsStorage: TotalAnalyticsStoring

    public init(
        friendStorage: FriendStoring? = nil,
        exerciseStorage: ExerciseStoring? = nil,
        totalAnalyticsStorage: TotalAnalyticsStoring? = nil
    ) {
        self.friendStorage = friendStorage ?? Container.shared.friendStorage()
        self.exerciseStorage = exerciseStorage ?? Container.shared.exerciseStorage()
        self.totalAnalyticsStorage = totalAnalyticsStorage ?? Container.shared.totalAnalyticsStorage()
    }

    /// - Parameters:
    ///   - friend: The friend to load data for.
    ///   - myWorkout: The current user's workout to compare against.
    ///   - now: Date used for "training days this month" computation. Defaults to `Date()`.
    public func execute(friend: Friend, myWorkout: Workout, now: Date = Date()) throws -> FriendComparison {
        let envelope = try friendStorage.loadEnvelope(for: friend.id)

        var myExercises: [Exercise] = []
        for category in MuscleCategoryGroup.allCases {
            myExercises.append(contentsOf: exerciseStorage.loadForWorkout(
                workoutId: myWorkout.id,
                category: category
            ))
        }
        let myAnalytics = totalAnalyticsStorage.loadAllAnalytics(for: myWorkout.id)

        let myMetrics = FriendMetricsCalculator.metrics(
            exercises: myExercises,
            analytics: myAnalytics,
            now: now
        )
        let friendMetrics = FriendMetricsCalculator.metrics(
            exercises: envelope.exercises,
            analytics: envelope.analytics,
            now: now
        )
        let categoryComparisons = FriendMetricsCalculator.categoryComparisons(
            myExercises: myExercises,
            friendExercises: envelope.exercises
        )

        return FriendComparison(
            myMetrics: myMetrics,
            friendMetrics: friendMetrics,
            categoryComparisons: categoryComparisons
        )
    }
}
