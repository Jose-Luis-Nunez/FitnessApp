import Foundation
import FitnessTestSupport
import Testing
import FitnessAnalytics
import FitnessCore
import SwiftData
@testable import FitnessPersistenceUI

/// The completed card's two presentation states both implement the project rule
/// that a failed read must stay distinguishable from a successful empty one, so
/// a retry is still possible and the failure stays visible. That rule is the
/// whole reason these types exist, and it is invisible in a snapshot.
@MainActor
// Pure logic, but this package has no native fast target — it is scheduled with
// the integration plan, and the tag says where it actually runs.
@Suite("Completed card load-outcome state", .tags(.integration))
struct CardLoadOutcomeStateTests {

    // MARK: - Session improvement

    @Test func loadedValueIsAdopted() {
        var sut = SessionImprovementCardState()
        sut.apply(.loaded(SessionImprovement(
            weightGain: 5,
            currentWeight: 55,
            repsGain: nil,
            currentReps: 8
        )))

        #expect(sut.improvement?.weightGain == 5)
        #expect(sut.improvement?.currentWeight == 55)
    }

    /// "Loaded, but nothing to compare" is a real answer and must replace a
    /// previous value.
    @Test func aSuccessfulEmptyResultClearsAPreviousValue() {
        var sut = SessionImprovementCardState()
        sut.apply(.loaded(SessionImprovement(
            weightGain: 5,
            currentWeight: 55,
            repsGain: nil,
            currentReps: 8
        )))
        sut.apply(.loaded(nil))

        #expect(sut.improvement == nil)
    }

    /// A failure must not look like "did not improve": the previous value stays
    /// so the next revision can retry instead of caching an empty state.
    @Test func aFailureKeepsThePreviousValue() {
        var sut = SessionImprovementCardState()
        sut.apply(.loaded(SessionImprovement(
            weightGain: 5,
            currentWeight: 55,
            repsGain: nil,
            currentReps: 8
        )))
        sut.apply(.failed)

        #expect(sut.improvement?.weightGain == 5)
    }

    @Test func aFailureWithNothingLoadedYetStaysEmpty() {
        var sut = SessionImprovementCardState()
        sut.apply(.failed)

        #expect(sut.improvement == nil)
    }

    // MARK: - Latest set progress

    @Test func expansionIsAllowedOnlyWhenSetsWereActuallyLoaded() {
        var sut = LatestSetProgressCardState()

        #expect(sut.apply(.loaded(nil)) == false)
        #expect(sut.setProgress.isEmpty)

        let entry = AnalyticsEntry(
            exerciseId: UUID(),
            date: Date(),
            setProgress: [
                SetProgress(status: .completedDone, currentReps: 10, weight: 60)
            ]
        )
        #expect(sut.apply(.loaded(entry)) == true)
        #expect(sut.setProgress.count == 1)
    }

    /// A failed read may still reveal previously loaded sets, but it must never
    /// make an empty details area look like a successful expansion.
    @Test func aFailureNeitherClearsNorFabricatesSets() {
        var sut = LatestSetProgressCardState()
        #expect(sut.apply(.failed) == false)
        #expect(sut.setProgress.isEmpty)

        let entry = AnalyticsEntry(
            exerciseId: UUID(),
            date: Date(),
            setProgress: [
                SetProgress(status: .completedDone, currentReps: 10, weight: 60)
            ]
        )
        _ = sut.apply(.loaded(entry))
        #expect(sut.apply(.failed) == true)
        #expect(sut.setProgress.count == 1)
    }
}
