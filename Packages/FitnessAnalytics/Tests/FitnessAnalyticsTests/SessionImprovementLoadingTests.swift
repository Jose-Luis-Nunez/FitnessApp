import Testing
import Foundation
@testable import FitnessAnalytics
import FitnessCore
import FitnessTestSupport

/// `loadSessionImprovement` is the only part of the completed-card feature that
/// touches storage, and it documents two contracts in its own header that
/// nothing else can prove: a failed read stays `.failed`, and the bounded result
/// never enters the history cache. Both are cheap to pin here because the
/// storage boundary is injectable.
@Suite("AnalyticsViewModel.loadSessionImprovement", .tags(.fast))
@MainActor
struct SessionImprovementLoadingTests {

    /// Fixed instant rather than `Date()`: this suite turns on day boundaries.
    private static let referenceDay = Date(timeIntervalSince1970: 1_767_225_600)

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(
            byAdding: .day,
            value: offset,
            to: Calendar.current.startOfDay(for: Self.referenceDay)
        )!
    }

    private func entry(
        _ exerciseId: UUID,
        _ dayOffset: Int,
        weight: Double,
        reps: Int
    ) -> AnalyticsEntry {
        AnalyticsEntry(
            exerciseId: exerciseId,
            date: day(dayOffset).addingTimeInterval(9 * 3600),
            setProgress: [
                SetProgress(status: .completedDone, currentReps: reps, weight: weight)
            ]
        )
    }

    private func makeSUT(
        _ storage: MockAnalyticsStorage
    ) -> AnalyticsViewModel {
        AnalyticsViewModel(
            storageService: storage,
            exerciseStorage: MockExerciseStorage(),
            workoutStorage: MockWorkoutStorage()
        )
    }

    // MARK: - Read path

    @Test func readsTheBoundedTwoDayPathAndNotTheFullHistory() throws {
        let id = UUID()
        let storage = MockAnalyticsStorage()
        storage.save(
            [entry(id, -1, weight: 50, reps: 8), entry(id, 0, weight: 55, reps: 10)],
            for: id
        )
        storage.resetLoadTracking()

        let outcome = makeSUT(storage).loadSessionImprovement(for: id, hasWeight: true)

        guard case let .loaded(improvement) = outcome else {
            Issue.record("expected a loaded outcome, got \(outcome)")
            return
        }
        #expect(improvement?.weightGain == 5)
        #expect(storage.recentLoadCallCount == 1)
        #expect(storage.recentLoadDayLimits == [2])
        #expect(storage.loadCallCount == 0)
    }

    @Test func anExerciseWithoutHistoryLoadsNothingToCompare() {
        let storage = MockAnalyticsStorage()
        let outcome = makeSUT(storage).loadSessionImprovement(
            for: UUID(),
            hasWeight: true
        )

        guard case let .loaded(improvement) = outcome else {
            Issue.record("expected a loaded outcome, got \(outcome)")
            return
        }
        #expect(improvement == nil)
    }

    // MARK: - Failure contract

    /// A read failure must stay distinguishable from "loaded, nothing to
    /// compare", so the card can retry instead of caching an empty state.
    @Test func aReadFailureIsSurfacedRatherThanReportedAsNoImprovement() {
        let id = UUID()
        let storage = MockAnalyticsStorage()
        storage.save([entry(id, 0, weight: 50, reps: 8)], for: id)
        storage.recentLoadFails = true

        let outcome = makeSUT(storage).loadSessionImprovement(for: id, hasWeight: true)

        guard case .failed = outcome else {
            Issue.record("expected a failed outcome, got \(outcome)")
            return
        }
    }

    @Test func aFailedReadIsNotCached() {
        let id = UUID()
        let storage = MockAnalyticsStorage()
        storage.save([entry(id, 0, weight: 50, reps: 8)], for: id)
        storage.recentLoadFails = true
        let sut = makeSUT(storage)

        _ = sut.loadSessionImprovement(for: id, hasWeight: true)
        storage.recentLoadFails = false
        let retry = sut.loadSessionImprovement(for: id, hasWeight: true)

        guard case let .loaded(improvement) = retry else {
            Issue.record("expected the retry to succeed, got \(retry)")
            return
        }
        #expect(improvement?.currentWeight == 50)
        #expect(storage.recentLoadCallCount == 2)
    }

    // MARK: - Cache contract

    /// The bounded read is partial. Consumers of `history` expect the complete
    /// series, so it must never be written into the history cache — otherwise
    /// the analytics screen renders two days as if they were everything.
    @Test func theBoundedResultNeverEntersTheHistoryCache() {
        let id = UUID()
        let storage = MockAnalyticsStorage()
        storage.save(
            [
                entry(id, -9, weight: 30, reps: 20),
                entry(id, -1, weight: 50, reps: 8),
                entry(id, 0, weight: 55, reps: 10)
            ],
            for: id
        )
        let sut = makeSUT(storage)

        _ = sut.loadSessionImprovement(for: id, hasWeight: true)

        #expect(sut.cachedEntries(for: id) == nil)
    }

    /// A full history that is already cached is reused rather than re-read: it
    /// is a superset of what the comparison needs.
    @Test func anExistingFullHistoryCacheIsReusedInsteadOfReadingAgain() throws {
        let id = UUID()
        let storage = MockAnalyticsStorage()
        storage.save(
            [entry(id, -1, weight: 50, reps: 8), entry(id, 0, weight: 55, reps: 10)],
            for: id
        )
        let sut = makeSUT(storage)
        _ = sut.loadAnalytics(for: id)
        storage.resetLoadTracking()

        let outcome = sut.loadSessionImprovement(for: id, hasWeight: true)

        guard case let .loaded(improvement) = outcome else {
            Issue.record("expected a loaded outcome, got \(outcome)")
            return
        }
        #expect(improvement?.weightGain == 5)
        #expect(storage.recentLoadCallCount == 0)
        #expect(storage.loadCallCount == 0)
    }
}
