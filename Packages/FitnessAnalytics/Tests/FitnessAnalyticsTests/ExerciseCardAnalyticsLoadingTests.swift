import Foundation
import os
import Testing
@testable import FitnessAnalytics
import FitnessCore
import FitnessTestSupport

@Suite("Exercise card analytics loading", .tags(.fast))
@MainActor
struct ExerciseCardAnalyticsLoadingTests {
    @Test func availabilityCheckLoadsNoAnalyticsPayloadAndCachesTrue() {
        let storage = MockAnalyticsStorage()
        let exerciseID = UUID()
        storage.save([entry(for: exerciseID)], for: exerciseID)
        storage.resetLoadTracking()
        let viewModel = AnalyticsViewModel(storageService: storage)

        #expect(availability(from: viewModel.loadAnalyticsHistoryAvailability(for: exerciseID)) == true)
        #expect(availability(from: viewModel.loadAnalyticsHistoryAvailability(for: exerciseID)) == true)

        #expect(storage.availabilityExerciseIDs == [exerciseID])
        #expect(storage.latestLoadCallCount == 0)
        #expect(storage.loadCallCount == 0)
        #expect(storage.batchLoadCallCount == 0)
    }

    @Test func successfulEmptyAvailabilityIsCached() {
        let storage = MockAnalyticsStorage()
        let exerciseID = UUID()
        let viewModel = AnalyticsViewModel(storageService: storage)

        #expect(availability(from: viewModel.loadAnalyticsHistoryAvailability(for: exerciseID)) == false)
        #expect(availability(from: viewModel.loadAnalyticsHistoryAvailability(for: exerciseID)) == false)

        #expect(storage.availabilityCallCount == 1)
        #expect(storage.latestLoadCallCount == 0)
        #expect(storage.loadCallCount == 0)
    }

    @Test func failedAvailabilityCheckRemainsRetryable() {
        let storage = MockAnalyticsStorage()
        let exerciseID = UUID()
        storage.save([entry(for: exerciseID)], for: exerciseID)
        storage.availabilityLoadFails = true
        let viewModel = AnalyticsViewModel(storageService: storage)

        #expect(isFailure(viewModel.loadAnalyticsHistoryAvailability(for: exerciseID)))
        storage.availabilityLoadFails = false
        #expect(availability(from: viewModel.loadAnalyticsHistoryAvailability(for: exerciseID)) == true)

        #expect(storage.availabilityCallCount == 2)
    }

    @Test func lastRunTapLoadsOnlyLatestEntryAndCachesIt() {
        let storage = MockAnalyticsStorage()
        let exerciseID = UUID()
        let older = entry(for: exerciseID, date: Date(timeIntervalSince1970: 100))
        let latest = entry(for: exerciseID, date: Date(timeIntervalSince1970: 200))
        storage.save([latest, older], for: exerciseID)
        storage.resetLoadTracking()
        let viewModel = AnalyticsViewModel(storageService: storage)

        #expect(availability(from: viewModel.loadAnalyticsHistoryAvailability(for: exerciseID)) == true)
        #expect(loadedEntry(from: viewModel.loadLatestEntry(for: exerciseID))?.id == latest.id)
        #expect(loadedEntry(from: viewModel.loadLatestEntry(for: exerciseID))?.id == latest.id)

        #expect(storage.availabilityCallCount == 1)
        #expect(storage.latestLoadedExerciseIDs == [exerciseID])
        #expect(storage.loadCallCount == 0)
    }

    @Test func successfulEmptyLatestEntryIsCached() {
        let storage = MockAnalyticsStorage()
        let exerciseID = UUID()
        let viewModel = AnalyticsViewModel(storageService: storage)

        let firstOutcome = viewModel.loadLatestEntry(for: exerciseID)
        let secondOutcome = viewModel.loadLatestEntry(for: exerciseID)

        #expect(isSuccessfulEmpty(firstOutcome))
        #expect(isSuccessfulEmpty(secondOutcome))

        #expect(storage.latestLoadCallCount == 1)
        #expect(storage.loadCallCount == 0)
    }

    @Test func failedLatestEntryReadRemainsRetryable() {
        let storage = MockAnalyticsStorage()
        let exerciseID = UUID()
        storage.save([entry(for: exerciseID)], for: exerciseID)
        storage.latestLoadFails = true
        let viewModel = AnalyticsViewModel(storageService: storage)

        #expect(isFailure(viewModel.loadLatestEntry(for: exerciseID)))
        storage.latestLoadFails = false
        #expect(loadedEntry(from: viewModel.loadLatestEntry(for: exerciseID)) != nil)

        #expect(storage.latestLoadCallCount == 2)
    }

    @Test func failedHistoryReloadLeavesLatestEntryRetryable() {
        let storage = MockAnalyticsStorage()
        let exerciseID = UUID()
        let latest = entry(for: exerciseID)
        storage.save([latest], for: exerciseID)
        let viewModel = AnalyticsViewModel(storageService: storage)
        _ = viewModel.loadAnalytics(for: exerciseID)
        storage.singleLoadFails = true

        #expect(!viewModel.reloadEntries(for: exerciseID))

        storage.singleLoadFails = false
        storage.resetLoadTracking()
        #expect(loadedEntry(from: viewModel.loadLatestEntry(for: exerciseID))?.id == latest.id)
        #expect(storage.latestLoadedExerciseIDs == [exerciseID])
    }

    /// Named after the read, not the gesture that triggers it: the card phases
    /// are the only card stage that needs the complete history, and the two
    /// weights below make the fixture contain an actual increase — without one
    /// there are no phases to return at all.
    @Test func loadingCardPhasesIsTheFirstFullHistoryRead() {
        let storage = MockAnalyticsStorage()
        let exerciseID = UUID()
        storage.save([
            entry(for: exerciseID, date: Date(timeIntervalSince1970: 100), weight: 20),
            entry(for: exerciseID, date: Date(timeIntervalSince1970: 200_000), weight: 30),
        ], for: exerciseID)
        storage.resetLoadTracking()
        let viewModel = AnalyticsViewModel(storageService: storage)

        _ = viewModel.loadAnalyticsHistoryAvailability(for: exerciseID)
        _ = viewModel.loadLatestEntry(for: exerciseID)
        #expect(storage.loadCallCount == 0)

        #expect(!viewModel.loadCardPhases(for: exerciseID, hasWeight: true).isEmpty)
        #expect(!viewModel.loadCardPhases(for: exerciseID, hasWeight: true).isEmpty)

        #expect(storage.loadCallCount == 1)
        #expect(storage.loadedExerciseIDs == [exerciseID])
        #expect(storage.batchLoadCallCount == 0)
    }

    /// An exercise trained only at one weight has no phases, and that empty
    /// result is exactly what hides the coaching-tip button.
    @Test func anExerciseWithoutAnIncreaseYieldsNoPhases() {
        let storage = MockAnalyticsStorage()
        let exerciseID = UUID()
        storage.save([
            entry(for: exerciseID, date: Date(timeIntervalSince1970: 100), weight: 20),
            entry(for: exerciseID, date: Date(timeIntervalSince1970: 200_000), weight: 20),
        ], for: exerciseID)
        let viewModel = AnalyticsViewModel(storageService: storage)

        #expect(viewModel.loadCardPhases(for: exerciseID, hasWeight: true).isEmpty)
    }

    @Test func fullHistoryAnswersLowerCacheStagesWithoutMoreReads() {
        let storage = MockAnalyticsStorage()
        let exerciseID = UUID()
        let latest = entry(for: exerciseID)
        storage.save([latest], for: exerciseID)
        let viewModel = AnalyticsViewModel(storageService: storage)

        #expect(viewModel.loadAnalytics(for: exerciseID).count == 1)
        storage.resetLoadTracking()

        #expect(availability(from: viewModel.loadAnalyticsHistoryAvailability(for: exerciseID)) == true)
        #expect(loadedEntry(from: viewModel.loadLatestEntry(for: exerciseID))?.id == latest.id)
        #expect(storage.availabilityCallCount == 0)
        #expect(storage.latestLoadCallCount == 0)
        #expect(storage.loadCallCount == 0)
    }

    @Test func confirmedWorkoutWriteInvalidatesOnlyAffectedExercise() {
        let storage = MockAnalyticsStorage()
        let changedID = UUID()
        let unchangedID = UUID()
        let viewModel = AnalyticsViewModel(storageService: storage)
        _ = viewModel.loadAnalyticsHistoryAvailability(for: changedID)
        _ = viewModel.loadAnalyticsHistoryAvailability(for: unchangedID)
        let changedRevision = viewModel.revisionSource(for: changedID)
        let unchangedRevision = viewModel.revisionSource(for: unchangedID)
        let changedValue = changedRevision.value
        let unchangedValue = unchangedRevision.value
        let unrelatedObservationFired = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            _ = unchangedRevision.value
        } onChange: {
            unrelatedObservationFired.withLock { $0 = true }
        }

        viewModel.publishPersistedEntries([entry(for: changedID)])

        #expect(availability(from: viewModel.loadAnalyticsHistoryAvailability(for: changedID)) == true)
        #expect(changedRevision.value != changedValue)
        #expect(unchangedRevision.value == unchangedValue)
        #expect(unrelatedObservationFired.withLock { !$0 })
    }

    @Test func cacheEvictsLeastRecentlyUsedExerciseBeyondBound() {
        let storage = MockAnalyticsStorage()
        let exerciseIDs = (0..<129).map { _ in UUID() }
        let viewModel = AnalyticsViewModel(storageService: storage)

        for exerciseID in exerciseIDs {
            _ = viewModel.loadAnalyticsHistoryAvailability(for: exerciseID)
        }
        storage.resetLoadTracking()

        _ = viewModel.loadAnalyticsHistoryAvailability(for: exerciseIDs[0])
        _ = viewModel.loadAnalyticsHistoryAvailability(for: exerciseIDs[128])

        #expect(storage.availabilityExerciseIDs == [exerciseIDs[0]])
    }

    @Test func failedPostWriteAvailabilityRefreshStillRespectsCacheBound() {
        let storage = MockAnalyticsStorage()
        let exerciseIDs = (0..<129).map { _ in UUID() }
        let viewModel = AnalyticsViewModel(
            storageService: storage,
            saveAnalyticsUseCase: SaveAnalyticsUseCase(analyticsStorage: storage)
        )
        for exerciseID in exerciseIDs.dropLast() {
            _ = viewModel.loadAnalyticsHistoryAvailability(for: exerciseID)
        }
        storage.availabilityLoadFails = true

        viewModel.saveAnalytics(
            exerciseId: exerciseIDs[128],
            setProgress: [SetProgress(status: .completedDone, currentReps: 10, weight: 20)]
        )

        storage.availabilityLoadFails = false
        storage.resetLoadTracking()
        _ = viewModel.loadAnalyticsHistoryAvailability(for: exerciseIDs[0])
        _ = viewModel.loadAnalyticsHistoryAvailability(for: exerciseIDs[127])
        #expect(storage.availabilityExerciseIDs == [exerciseIDs[0]])
    }

    private func entry(
        for exerciseID: UUID,
        date: Date = Date(),
        weight: Double = 20
    ) -> AnalyticsEntry {
        AnalyticsEntry(
            exerciseId: exerciseID,
            date: date,
            setProgress: [
                SetProgress(status: .completedDone, currentReps: 10, weight: weight),
                SetProgress(status: .completedDone, currentReps: 10, weight: weight),
                SetProgress(status: .completedDone, currentReps: 10, weight: weight),
            ]
        )
    }

    private func loadedEntry(
        from outcome: LatestAnalyticsEntryLoadOutcome
    ) -> AnalyticsEntry? {
        guard case let .loaded(entry) = outcome else { return nil }
        return entry
    }

    private func availability(
        from outcome: AnalyticsHistoryAvailabilityOutcome
    ) -> Bool? {
        guard case let .loaded(hasHistory) = outcome else { return nil }
        return hasHistory
    }

    private func isSuccessfulEmpty(_ outcome: LatestAnalyticsEntryLoadOutcome) -> Bool {
        guard case .loaded(nil) = outcome else { return false }
        return true
    }

    private func isFailure<Value: Sendable>(_ outcome: AnalyticsLoadOutcome<Value>) -> Bool {
        guard case .failed = outcome else { return false }
        return true
    }
}
