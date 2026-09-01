import Testing
import Foundation
@testable import FitnessAnalytics
import FitnessCore
import FitnessTestSupport

// MARK: - Helpers

/// Fixed clock and fixed timezone. These suites turn entirely on day
/// boundaries, so the one thing they must not depend on is when they run.
private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// 2026-01-01 00:00 UTC.
private let referenceDay = Date(timeIntervalSince1970: 1_767_225_600)

private func day(_ offset: Int) -> Date {
    testCalendar.date(
        byAdding: .day,
        value: offset,
        to: testCalendar.startOfDay(for: referenceDay)
    )!
}

private func entry(
    _ dayOffset: Int,
    _ sets: [(weight: Double, reps: Int)]
) -> AnalyticsEntry {
    AnalyticsEntry(
        exerciseId: UUID(),
        date: day(dayOffset).addingTimeInterval(9 * 3600),
        setProgress: sets.map {
            SetProgress(status: .completedDone, currentReps: $0.reps, weight: $0.weight)
        }
    )
}

// MARK: - Day grouping

/// `DayTrainingSession` backs both the weight and the reps card, so a mistake
/// here changes two shipped features at once.
@Suite("DayTrainingSession.sessions", .tags(.fast))
struct DayTrainingSessionTests {

    @Test func groupsSeveralEntriesOfOneDayIntoOneSession() {
        let sessions = DayTrainingSession.sessions(
            from: [
                entry(-1, [(40, 10)]),
                entry(-1, [(45, 8)]),
                entry(0, [(50, 6)])
            ],
            calendar: testCalendar
        )

        #expect(sessions.count == 2)
        #expect(sessions.first?.maxWeight == 45)
        #expect(sessions.last?.maxWeight == 50)
    }

    @Test func ordersOldestFirst() {
        let sessions = DayTrainingSession.sessions(
            from: [
                entry(0, [(50, 6)]),
                entry(-2, [(30, 12)]),
                entry(-1, [(40, 10)])
            ],
            calendar: testCalendar
        )

        #expect(sessions.map(\.maxWeight) == [30, 40, 50])
    }

    @Test func dropsDaysWithoutARecordedSet() {
        let sessions = DayTrainingSession.sessions(from: [entry(0, [])], calendar: testCalendar)
        #expect(sessions.isEmpty)
    }

    @Test func minRepsAtMaxWeightIgnoresLighterSets() {
        let sessions = DayTrainingSession.sessions(
            from: [
                entry(0, [(50, 5), (50, 7), (40, 20)])
            ],
            calendar: testCalendar
        )

        #expect(sessions.first?.maxWeight == 50)
        #expect(sessions.first?.countAtMaxWeight == 2)
        #expect(sessions.first?.minRepsAtMaxWeight == 5)
        #expect(sessions.first?.maxReps == 20)
        #expect(sessions.first?.totalRepsAtMaxWeight == 12)
    }

    /// A day counts as bilateral only when *every* one of its entries resolves
    /// into pairs; one legacy entry falls the whole day back to set-based
    /// figures.
    @Test func oneNonBilateralEntryMakesTheWholeDayUnilateral() {
        let bilateral = AnalyticsEntry(
            exerciseId: UUID(),
            date: day(0),
            setProgress: [
                SetProgress(status: .completedDone, currentReps: 10, weight: 20, side: .left, logicalSetIndex: 0),
                SetProgress(status: .completedDone, currentReps: 10, weight: 20, side: .right, logicalSetIndex: 0)
            ]
        )
        let legacy = entry(0, [(20, 10)])

        #expect(
            DayTrainingSession
                .sessions(from: [bilateral], calendar: testCalendar)
                .first?.isBilateral == true
        )
        #expect(
            DayTrainingSession
                .sessions(from: [bilateral, legacy], calendar: testCalendar)
                .first?.isBilateral == false
        )
    }
}

// MARK: - Improvement derivation

@Suite("AnalyticsViewModel.improvement", .tags(.fast))
@MainActor
struct SessionImprovementDerivationTests {

    @Test func noHistoryYieldsNoImprovement() {
        #expect(AnalyticsViewModel.improvement(from: [], hasWeight: true, calendar: testCalendar) == nil)
    }

    /// A first-ever training has nothing to compare against, but its current
    /// figures are still reported so the card can show them.
    @Test func singleSessionReportsCurrentFiguresWithoutGains() throws {
        let result = try #require(
            AnalyticsViewModel.improvement(from: [entry(0, [(50, 8)])], hasWeight: true)
        )

        #expect(result.weightGain == nil)
        #expect(result.repsGain == nil)
        #expect(result.currentWeight == 50)
        #expect(result.currentReps == 8)
        #expect(result.isEmpty)
    }

    @Test func reportsGainsAgainstThePreviousTrainingDay() throws {
        let result = try #require(
            AnalyticsViewModel.improvement(
                from: [entry(-1, [(50, 8)]), entry(0, [(55, 10)])],
                hasWeight: true,
                calendar: testCalendar
            )
        )

        #expect(result.weightGain == 5)
        #expect(result.repsGain == 2)
        #expect(result.isEmpty == false)
    }

    /// Only gains are represented: a decrease must read as "did not improve",
    /// never as a negative delta.
    @Test func aDecreaseIsReportedAsNoGainRatherThanANegativeDelta() throws {
        let result = try #require(
            AnalyticsViewModel.improvement(
                from: [entry(-1, [(60, 12)]), entry(0, [(50, 8)])],
                hasWeight: true,
                calendar: testCalendar
            )
        )

        #expect(result.weightGain == nil)
        #expect(result.repsGain == nil)
        #expect(result.currentWeight == 50)
        #expect(result.isEmpty)
    }

    @Test func anUnchangedSessionIsNotAnImprovement() throws {
        let result = try #require(
            AnalyticsViewModel.improvement(
                from: [entry(-1, [(50, 8)]), entry(0, [(50, 8)])],
                hasWeight: true,
                calendar: testCalendar
            )
        )

        #expect(result.isEmpty)
    }

    /// A weighted exercise compares reps *at the working weight*; a bodyweight
    /// exercise has no working weight and compares the day's best rep count.
    @Test func hasWeightSelectsWhichRepFigureIsCompared() throws {
        let history = [
            entry(-1, [(50, 5), (20, 30)]),
            entry(0, [(50, 6), (20, 20)])
        ]

        let weighted = try #require(
            AnalyticsViewModel.improvement(
                from: history,
                hasWeight: true,
                calendar: testCalendar
            )
        )
        #expect(weighted.currentReps == 6)
        #expect(weighted.repsGain == 1)

        let bodyweight = try #require(
            AnalyticsViewModel.improvement(
                from: history,
                hasWeight: false,
                calendar: testCalendar
            )
        )
        #expect(bodyweight.currentReps == 20)
        #expect(bodyweight.repsGain == nil)
    }

    /// Only the two most recent days matter, however long the history is.
    @Test func comparesOnlyTheTwoMostRecentDays() throws {
        let result = try #require(
            AnalyticsViewModel.improvement(
                from: [
                    entry(-9, [(100, 20)]),
                    entry(-5, [(90, 15)]),
                    entry(-1, [(50, 8)]),
                    entry(0, [(55, 9)])
                ],
                hasWeight: true,
                calendar: testCalendar
            )
        )

        #expect(result.weightGain == 5)
        #expect(result.repsGain == 1)
    }
}
