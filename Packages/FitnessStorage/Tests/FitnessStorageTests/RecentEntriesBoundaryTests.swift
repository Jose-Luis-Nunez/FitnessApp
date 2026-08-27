import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@testable import FitnessStorageTestSupport
@testable import FitnessStorage

/// Minimal conformance that inherits the protocol's derived implementation of
/// `loadRecentEntries`, so the default and the SwiftData override can be held to
/// the same table below.
@MainActor
private final class HistoryOnlyAnalyticsStorage: AnalyticsStoring {
    var entries: [AnalyticsEntry] = []

    func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {
        self.entries = entries
    }

    func load(for exerciseId: UUID) -> [AnalyticsEntry] { entries }
}

/// The day boundary for a bounded read exists twice: once as the protocol
/// default that mocks and test doubles inherit, once as a paged SwiftData fetch.
/// Two hand-written copies of one rule drift unless something asserts they
/// agree — which is what this suite is for.
@Suite("loadRecentEntries day boundary", .tags(.integration))
@MainActor
struct RecentEntriesBoundaryTests {

    private let container: ModelContainer
    /// Both implementations resolve days with `Calendar.current`, so the suite
    /// has to use it too — but it anchors to a fixed instant rather than `Date()`
    /// so a run near midnight cannot shift a fixture across a day boundary.
    private let calendar = Calendar.current
    /// 2026-01-01 12:00 UTC.
    private let reference = Date(timeIntervalSince1970: 1_767_268_800)

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(
            byAdding: .day,
            value: offset,
            to: calendar.startOfDay(for: reference)
        )!
    }

    /// Two entries on each of four days, plus a same-day pair that must not be
    /// split by the boundary.
    private func fixture(for exerciseId: UUID) -> [AnalyticsEntry] {
        [-3, -2, -1, 0].flatMap { offset in
            [1, 5].map { hour in
                TestHelpers.makeAnalyticsEntry(
                    exerciseId: exerciseId,
                    date: day(offset).addingTimeInterval(TimeInterval(hour) * 3600)
                )
            }
        }
    }

    /// Both implementations, so every expectation below is checked twice.
    private func subjects(
        for exerciseId: UUID,
        entries: [AnalyticsEntry]
    ) -> [(name: String, storage: any AnalyticsStoring)] {
        let swiftData = AnalyticsStorageService(container: container)
        swiftData.save(entries, for: exerciseId)

        let derived = HistoryOnlyAnalyticsStorage()
        derived.save(entries, for: exerciseId)

        return [("SwiftData override", swiftData), ("protocol default", derived)]
    }

    @Test func returnsEveryEntryOfTheRequestedDaysAndNothingOlder() throws {
        let exerciseId = UUID()
        let entries = fixture(for: exerciseId)

        for subject in subjects(for: exerciseId, entries: entries) {
            let loaded = try subject.storage.loadRecentEntries(
                for: exerciseId,
                dayLimit: 2
            )
            let days = Set(loaded.map { calendar.startOfDay(for: $0.date) })

            #expect(loaded.count == 4, "\(subject.name)")
            #expect(days == Set([day(-1), day(0)]), "\(subject.name)")
        }
    }

    @Test func aDayLimitOfOneKeepsBothEntriesOfTheNewestDay() throws {
        let exerciseId = UUID()
        let entries = fixture(for: exerciseId)

        for subject in subjects(for: exerciseId, entries: entries) {
            let loaded = try subject.storage.loadRecentEntries(
                for: exerciseId,
                dayLimit: 1
            )
            #expect(loaded.count == 2, "\(subject.name)")
            #expect(
                loaded.allSatisfy { calendar.startOfDay(for: $0.date) == day(0) },
                "\(subject.name)"
            )
        }
    }

    @Test(arguments: [0, -1])
    func aNonPositiveDayLimitReadsNothing(_ dayLimit: Int) throws {
        let exerciseId = UUID()
        let entries = fixture(for: exerciseId)

        for subject in subjects(for: exerciseId, entries: entries) {
            let loaded = try subject.storage.loadRecentEntries(
                for: exerciseId,
                dayLimit: dayLimit
            )
            #expect(loaded.isEmpty, "\(subject.name)")
        }
    }

    @Test func aLimitBeyondTheAvailableHistoryReturnsAllOfIt() throws {
        let exerciseId = UUID()
        let entries = fixture(for: exerciseId)

        for subject in subjects(for: exerciseId, entries: entries) {
            let loaded = try subject.storage.loadRecentEntries(
                for: exerciseId,
                dayLimit: 99
            )
            #expect(loaded.count == entries.count, "\(subject.name)")
        }
    }

    @Test func anExerciseWithoutHistoryReadsNothing() throws {
        let exerciseId = UUID()

        for subject in subjects(for: exerciseId, entries: []) {
            let loaded = try subject.storage.loadRecentEntries(
                for: exerciseId,
                dayLimit: 2
            )
            #expect(loaded.isEmpty, "\(subject.name)")
        }
    }

    /// More entries than one fetch page, so the override's paging loop actually
    /// runs more than once for a single day.
    @Test func pagesUntilTheDayBoundaryIsReachedRatherThanStoppingAtOnePage() throws {
        let exerciseId = UUID()
        let entries = (0..<80).map { index in
            TestHelpers.makeAnalyticsEntry(
                exerciseId: exerciseId,
                date: day(0).addingTimeInterval(TimeInterval(index) * 60)
            )
        }

        for subject in subjects(for: exerciseId, entries: entries) {
            let loaded = try subject.storage.loadRecentEntries(
                for: exerciseId,
                dayLimit: 1
            )
            #expect(loaded.count == 80, "\(subject.name)")
        }
    }
}
