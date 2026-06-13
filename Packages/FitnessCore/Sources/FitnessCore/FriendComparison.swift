import Foundation

/// Per-category exercise count for one side of the comparison.
public struct CategoryCount: Sendable {
    public let category: MuscleCategoryGroup
    public let count: Int

    public init(category: MuscleCategoryGroup, count: Int) {
        self.category = category
        self.count = count
    }
}

/// Aggregated comparison metrics derived from a single `WorkoutShareEnvelope`.
public struct FriendComparisonMetrics: Sendable {
    /// Exercises per muscle category, ordered by `MuscleCategoryGroup.allCases`.
    public let categoryCounts: [CategoryCount]
    /// Number of distinct calendar days in the current month on which at
    /// least one analytics entry was recorded. Computed from `analytics.date`
    /// relative to the injected `now`.
    public let trainingDaysThisMonth: Int
    /// Total number of exercises in the workout.
    public let totalExercises: Int

    public init(categoryCounts: [CategoryCount], trainingDaysThisMonth: Int, totalExercises: Int) {
        self.categoryCounts = categoryCounts
        self.trainingDaysThisMonth = trainingDaysThisMonth
        self.totalExercises = totalExercises
    }
}

/// A pair of matching exercises (same name, case-insensitive) from both sides.
public struct ExercisePair: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let myWeight: Double
    public let myReps: Int
    public let friendWeight: Double
    public let friendReps: Int

    public init(name: String, myWeight: Double, myReps: Int, friendWeight: Double, friendReps: Int) {
        self.id = UUID()
        self.name = name
        self.myWeight = myWeight
        self.myReps = myReps
        self.friendWeight = friendWeight
        self.friendReps = friendReps
    }
}

/// Per-category drill-down: only exercises whose names appear in both sides.
public struct FriendCategoryComparison: Sendable {
    public let category: MuscleCategoryGroup
    /// Matched exercise pairs ordered by name.
    public let matchedPairs: [ExercisePair]
    /// Count of exercises on the friend's side that have no name-match on my side.
    public let friendExclusiveCount: Int

    public init(category: MuscleCategoryGroup, matchedPairs: [ExercisePair], friendExclusiveCount: Int) {
        self.category = category
        self.matchedPairs = matchedPairs
        self.friendExclusiveCount = friendExclusiveCount
    }
}

/// Full comparison result used by `FriendComparisonView`.
public struct FriendComparison: Sendable {
    public let myMetrics: FriendComparisonMetrics
    public let friendMetrics: FriendComparisonMetrics
    public let categoryComparisons: [FriendCategoryComparison]

    public init(
        myMetrics: FriendComparisonMetrics,
        friendMetrics: FriendComparisonMetrics,
        categoryComparisons: [FriendCategoryComparison]
    ) {
        self.myMetrics = myMetrics
        self.friendMetrics = friendMetrics
        self.categoryComparisons = categoryComparisons
    }
}
