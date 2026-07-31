import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage
@Suite("AnalyticsStorageService", .tags(.integration))
@MainActor
struct AnalyticsStorageServiceTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func makeSUT() -> AnalyticsStorageService {
        AnalyticsStorageService(container: container)
    }

    // MARK: - Save & Load

    @Test func saveThenLoadReturnsMatchingEntries() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let entry = TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId)

        sut.save([entry], for: exerciseId)
        let loaded = sut.load(for: exerciseId)

        #expect(loaded.count == 1)
        #expect(loaded.first?.exerciseId == exerciseId)
        #expect(loaded.first?.id == entry.id)
    }

    @Test func loadReturnsEntriesSortedByDate() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let calendar = Calendar.current

        let olderDate = calendar.date(byAdding: .day, value: -3, to: Date())!
        let middleDate = calendar.date(byAdding: .day, value: -1, to: Date())!
        let newerDate = Date()

        let entries = [
            TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId, date: newerDate),
            TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId, date: olderDate),
            TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId, date: middleDate)
        ]

        sut.save(entries, for: exerciseId)
        let loaded = sut.load(for: exerciseId)

        #expect(loaded.count == 3)
        #expect(loaded[0].date <= loaded[1].date)
        #expect(loaded[1].date <= loaded[2].date)
    }

    @Test func saveEmptyArrayClearsPreviousEntries() {
        let sut = makeSUT()
        let exerciseId = UUID()

        sut.save([TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId)], for: exerciseId)
        #expect(sut.load(for: exerciseId).count == 1)

        sut.save([], for: exerciseId)
        #expect(sut.load(for: exerciseId).count == 0)
    }

    @Test func saveReplacesAllPreviousEntries() {
        let sut = makeSUT()
        let exerciseId = UUID()

        let original = [TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId)]
        sut.save(original, for: exerciseId)

        let replacement = [
            TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId),
            TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId),
            TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId)
        ]
        sut.save(replacement, for: exerciseId)

        let loaded = sut.load(for: exerciseId)
        #expect(loaded.count == 3)
        #expect(!loaded.contains { $0.id == original.first!.id })
    }

    // MARK: - Set Progress Persistence

    @Test func allSetStatusTypesRoundtrip() {
        let sut = makeSUT()
        let exerciseId = UUID()

        let progress: [SetProgress] = [
            SetProgress(status: .notStarted, currentReps: 0, weight: 0),
            SetProgress(status: .inProgress, currentReps: 5, weight: 30),
            SetProgress(status: .completedDone, currentReps: 10, weight: 60),
            SetProgress(status: .completedLess, currentReps: 7, weight: 60),
            SetProgress(status: .completedMore, currentReps: 15, weight: 60)
        ]

        let entry = AnalyticsEntry(exerciseId: exerciseId, date: Date(), setProgress: progress)
        sut.save([entry], for: exerciseId)

        let loaded = sut.load(for: exerciseId).first!.setProgress
        #expect(loaded.count == 5)
        #expect(loaded[0].status == .notStarted)
        #expect(loaded[1].status == .inProgress)
        #expect(loaded[2].status == .completedDone)
        #expect(loaded[3].status == .completedLess)
        #expect(loaded[4].status == .completedMore)
    }

    @Test func setProgressOrderPreservedAcrossSave() {
        let sut = makeSUT()
        let exerciseId = UUID()

        let weights: [Double] = [100, 50, 75, 25, 90]
        let progress = weights.map { SetProgress(status: .completedDone, currentReps: 10, weight: $0) }

        let entry = AnalyticsEntry(exerciseId: exerciseId, date: Date(), setProgress: progress)
        sut.save([entry], for: exerciseId)

        let loaded = sut.load(for: exerciseId).first!.setProgress
        #expect(loaded.map(\.weight) == weights)
    }

    @Test func zeroWeightAndZeroRepsRoundtrip() {
        let sut = makeSUT()
        let exerciseId = UUID()

        let progress = [SetProgress(status: .notStarted, currentReps: 0, weight: 0)]
        let entry = AnalyticsEntry(exerciseId: exerciseId, date: Date(), setProgress: progress)
        sut.save([entry], for: exerciseId)

        let loaded = sut.load(for: exerciseId).first!.setProgress.first!
        #expect(loaded.weight == 0)
        #expect(loaded.currentReps == 0)
    }

    // MARK: - Isolation

    @Test func entriesForDifferentExercisesDoNotInterfere() {
        let sut = makeSUT()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        sut.save([TestHelpers.makeAnalyticsEntry(exerciseId: id1)], for: id1)
        sut.save([
            TestHelpers.makeAnalyticsEntry(exerciseId: id2),
            TestHelpers.makeAnalyticsEntry(exerciseId: id2)
        ], for: id2)

        #expect(sut.load(for: id1).count == 1)
        #expect(sut.load(for: id2).count == 2)
        #expect(sut.load(for: id3).count == 0)
    }

    @Test func savingForOneExerciseDoesNotAffectAnother() {
        let sut = makeSUT()
        let id1 = UUID()
        let id2 = UUID()

        sut.save([TestHelpers.makeAnalyticsEntry(exerciseId: id1)], for: id1)
        sut.save([TestHelpers.makeAnalyticsEntry(exerciseId: id2)], for: id2)

        sut.save([], for: id1)

        #expect(sut.load(for: id1).count == 0)
        #expect(sut.load(for: id2).count == 1)
    }

    // MARK: - Multiple Entries

    @Test func multipleEntriesOnSameDayPreserved() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let today = Date()

        let entries = [
            AnalyticsEntry(exerciseId: exerciseId, date: today, setProgress: [
                SetProgress(status: .completedDone, currentReps: 10, weight: 50)
            ]),
            AnalyticsEntry(exerciseId: exerciseId, date: today, setProgress: [
                SetProgress(status: .completedDone, currentReps: 12, weight: 55)
            ])
        ]

        sut.save(entries, for: exerciseId)
        let loaded = sut.load(for: exerciseId)

        #expect(loaded.count == 2)
    }

    @Test func workoutBatchAppendsAllExercisesWithoutReplacingHistory() {
        let sut = makeSUT()
        let firstID = UUID()
        let secondID = UUID()
        let existing = TestHelpers.makeAnalyticsEntry(exerciseId: firstID)
        let firstNew = TestHelpers.makeAnalyticsEntry(exerciseId: firstID)
        let secondNew = TestHelpers.makeAnalyticsEntry(exerciseId: secondID)
        sut.save([existing], for: firstID)

        let succeeded = sut.appendWorkoutAnalytics([firstNew, secondNew])

        #expect(succeeded)
        #expect(Set(sut.load(for: firstID).map(\.id)) == [existing.id, firstNew.id])
        #expect(sut.load(for: secondID).map(\.id) == [secondNew.id])
    }

    @Test func largeNumberOfSetsRoundtrip() {
        let sut = makeSUT()
        let exerciseId = UUID()

        let progress = (1...20).map {
            SetProgress(status: .completedDone, currentReps: $0, weight: Double($0) * 5)
        }

        let entry = AnalyticsEntry(exerciseId: exerciseId, date: Date(), setProgress: progress)
        sut.save([entry], for: exerciseId)

        let loaded = sut.load(for: exerciseId).first!
        #expect(loaded.setProgress.count == 20)
        #expect(loaded.setProgress.last!.currentReps == 20)
        #expect(loaded.setProgress.last!.weight == 100)
    }

    // MARK: - Date Persistence

    @Test func dateRoundtripPreservesDayAccuracy() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let calendar = Calendar.current

        let specificDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 14, minute: 30))!
        let entry = TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId, date: specificDate)
        sut.save([entry], for: exerciseId)

        let loaded = sut.load(for: exerciseId).first!
        #expect(calendar.isDate(loaded.date, inSameDayAs: specificDate))
    }

    // MARK: - Persistence Across Service Instances

    @Test func dataPersistedAcrossServiceInstances() {
        let exerciseId = UUID()

        let sut1 = makeSUT()
        sut1.save([TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId)], for: exerciseId)

        let sut2 = makeSUT()
        let loaded = sut2.load(for: exerciseId)
        #expect(loaded.count == 1)
    }
}
