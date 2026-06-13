import Testing
import Foundation
@testable import FitnessCore

@Suite("FriendMetricsCalculator")
struct FriendMetricsCalculatorTests {

    // Fixed "now" so tests are deterministic regardless of when they run.
    private let now: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 14
        return Calendar.current.date(from: comps)!
    }()

    // MARK: - Helpers

    private func makeExercise(
        name: String = "Bench Press",
        category: MuscleCategoryGroup = .chest,
        weight: Double = 60,
        reps: Int = 10
    ) -> Exercise {
        Exercise(
            id: UUID(),
            name: name,
            weight: weight,
            reps: reps,
            sets: 3,
            seatSetting: nil,
            noSeats: false,
            isCompleted: false,
            iconName: category.defaultIconName,
            category: category
        )
    }

    private func makeAnalyticsEntry(daysOffset: Int) -> AnalyticsEntry {
        let date = Calendar.current.date(byAdding: .day, value: daysOffset, to: now)!
        return AnalyticsEntry(
            exerciseId: UUID(),
            date: date,
            setProgress: []
        )
    }

    // MARK: - metrics: category counts

    @Test("Category counts are zero when no exercises")
    func metricsEmptyExercises() {
        let result = FriendMetricsCalculator.metrics(exercises: [], analytics: [], now: now)

        #expect(result.totalExercises == 0)
        for cat in MuscleCategoryGroup.allCases {
            let count = result.categoryCounts.first { $0.category == cat }?.count ?? -1
            #expect(count == 0)
        }
    }

    @Test("Category counts reflect exercise distribution")
    func metricsCategoryCounts() {
        let exercises = [
            makeExercise(category: .chest),
            makeExercise(category: .chest),
            makeExercise(category: .arms),
        ]
        let result = FriendMetricsCalculator.metrics(exercises: exercises, analytics: [], now: now)

        #expect(result.totalExercises == 3)
        #expect(result.categoryCounts.first { $0.category == .chest }?.count == 2)
        #expect(result.categoryCounts.first { $0.category == .arms }?.count == 1)
        #expect(result.categoryCounts.first { $0.category == .back }?.count == 0)
    }

    // MARK: - metrics: training days this month

    @Test("Training days counts distinct days in current month only")
    func metricsTrainingDaysCurrentMonthOnly() {
        let entries = [
            makeAnalyticsEntry(daysOffset: 0),   // today — in month
            makeAnalyticsEntry(daysOffset: 0),   // same day again — should not double-count
            makeAnalyticsEntry(daysOffset: -1),  // yesterday — in month
            makeAnalyticsEntry(daysOffset: -40), // last month — excluded
        ]
        let result = FriendMetricsCalculator.metrics(exercises: [], analytics: entries, now: now)

        #expect(result.trainingDaysThisMonth == 2) // today + yesterday
    }

    @Test("Training days is zero when no analytics in current month")
    func metricsTrainingDaysZeroWhenNoEntries() {
        let entries = [makeAnalyticsEntry(daysOffset: -40)]
        let result = FriendMetricsCalculator.metrics(exercises: [], analytics: entries, now: now)
        #expect(result.trainingDaysThisMonth == 0)
    }

    // MARK: - categoryComparisons: matching

    @Test("Matched pairs are found by case-insensitive name")
    func categoryComparisonsCaseInsensitiveMatch() {
        let mine = [makeExercise(name: "Bench Press", category: .chest, weight: 80, reps: 8)]
        let theirs = [makeExercise(name: "bench press", category: .chest, weight: 60, reps: 10)]

        let comps = FriendMetricsCalculator.categoryComparisons(myExercises: mine, friendExercises: theirs)
        let chestComp = comps.first { $0.category == .chest }

        #expect(chestComp != nil)
        #expect(chestComp?.matchedPairs.count == 1)
        #expect(chestComp?.matchedPairs.first?.myWeight == 80)
        #expect(chestComp?.matchedPairs.first?.friendWeight == 60)
        #expect(chestComp?.friendExclusiveCount == 0)
    }

    @Test("Friend-exclusive count reflects unmatched friend exercises")
    func categoryComparisonsFriendExclusive() {
        let mine = [makeExercise(name: "Bench Press", category: .chest)]
        let theirs = [
            makeExercise(name: "Bench Press", category: .chest),
            makeExercise(name: "Chest Fly", category: .chest),
        ]

        let comps = FriendMetricsCalculator.categoryComparisons(myExercises: mine, friendExercises: theirs)
        let chestComp = comps.first { $0.category == .chest }

        #expect(chestComp?.matchedPairs.count == 1)
        #expect(chestComp?.friendExclusiveCount == 1)
    }

    @Test("Category with no exercises on either side is excluded")
    func categoryComparisonsExcludesEmptyCategories() {
        let mine = [makeExercise(category: .arms)]
        let theirs = [makeExercise(category: .arms)]

        let comps = FriendMetricsCalculator.categoryComparisons(myExercises: mine, friendExercises: theirs)

        let categories = comps.map(\.category)
        #expect(categories.contains(.arms))
        #expect(!categories.contains(.chest))
        #expect(!categories.contains(.back))
        #expect(!categories.contains(.legs))
        #expect(!categories.contains(.abs))
    }

    @Test("No matches when names differ entirely")
    func categoryComparisonsNoMatch() {
        let mine = [makeExercise(name: "Pull-Up", category: .back)]
        let theirs = [makeExercise(name: "Row", category: .back)]

        let comps = FriendMetricsCalculator.categoryComparisons(myExercises: mine, friendExercises: theirs)
        let backComp = comps.first { $0.category == .back }

        #expect(backComp?.matchedPairs.isEmpty == true)
        #expect(backComp?.friendExclusiveCount == 1)
    }

    @Test("Whitespace trimming in name matching")
    func categoryComparisonsWhitespaceTrimming() {
        let mine = [makeExercise(name: "  Squat  ", category: .legs)]
        let theirs = [makeExercise(name: "Squat", category: .legs)]

        let comps = FriendMetricsCalculator.categoryComparisons(myExercises: mine, friendExercises: theirs)
        let legsComp = comps.first { $0.category == .legs }

        #expect(legsComp?.matchedPairs.count == 1)
    }
}
