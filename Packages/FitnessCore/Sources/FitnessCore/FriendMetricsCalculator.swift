import Foundation

/// Stateless calculator that derives `FriendComparisonMetrics` and
/// `FriendCategoryComparison` from raw exercise/analytics arrays.
/// All inputs are value types; `now` is injected for testability.
public enum FriendMetricsCalculator {

    public static func metrics(
        exercises: [Exercise],
        analytics: [AnalyticsEntry],
        now: Date = Date()
    ) -> FriendComparisonMetrics {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        let distinctDays = Set(
            analytics
                .filter {
                    let m = calendar.component(.month, from: $0.date)
                    let y = calendar.component(.year, from: $0.date)
                    return m == currentMonth && y == currentYear
                }
                .map { calendar.startOfDay(for: $0.date) }
        ).count

        let categoryCounts = MuscleCategoryGroup.allCases.map { cat in
            CategoryCount(
                category: cat,
                count: exercises.filter { $0.category == cat }.count
            )
        }

        return FriendComparisonMetrics(
            categoryCounts: categoryCounts,
            trainingDaysThisMonth: distinctDays,
            totalExercises: exercises.count
        )
    }

    /// Produces per-category comparisons, matching exercises by name
    /// (case-insensitive, whitespace-trimmed). Only categories where at least
    /// one side has exercises are included.
    public static func categoryComparisons(
        myExercises: [Exercise],
        friendExercises: [Exercise]
    ) -> [FriendCategoryComparison] {
        MuscleCategoryGroup.allCases.compactMap { cat in
            let mine = myExercises.filter { $0.category == cat }
            let theirs = friendExercises.filter { $0.category == cat }
            guard !mine.isEmpty || !theirs.isEmpty else { return nil }

            let myByName = Dictionary(
                grouping: mine,
                by: { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
            ).mapValues { $0.first! }

            var matchedPairs: [ExercisePair] = []
            var matchedFriendNames: Set<String> = []

            for friendEx in theirs {
                let key = friendEx.name.trimmingCharacters(in: .whitespaces).lowercased()
                if let myEx = myByName[key] {
                    matchedPairs.append(ExercisePair(
                        name: friendEx.name,
                        myWeight: myEx.weight,
                        myReps: myEx.reps,
                        friendWeight: friendEx.weight,
                        friendReps: friendEx.reps
                    ))
                    matchedFriendNames.insert(key)
                }
            }

            matchedPairs.sort { $0.name < $1.name }

            let friendExclusive = theirs.filter {
                !matchedFriendNames.contains($0.name.trimmingCharacters(in: .whitespaces).lowercased())
            }.count

            return FriendCategoryComparison(
                category: cat,
                matchedPairs: matchedPairs,
                friendExclusiveCount: friendExclusive
            )
        }
    }
}
