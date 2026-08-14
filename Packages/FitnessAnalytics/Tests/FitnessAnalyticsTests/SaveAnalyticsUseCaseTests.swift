import Testing
import Foundation
import FitnessCore
@testable import FitnessAnalytics
import FitnessTestSupport
@Suite("SaveAnalyticsUseCase", .tags(.fast))
@MainActor
struct SaveAnalyticsUseCaseTests {

    private func makeSUT() -> (SaveAnalyticsUseCase, MockAnalyticsStorage) {
        let mockStorage = MockAnalyticsStorage()
        let sut = SaveAnalyticsUseCase(analyticsStorage: mockStorage)
        return (sut, mockStorage)
    }

    @Test func executeCreatesEntryWithProvidedDateAndPreservesAllSets() throws {
        let (sut, storage) = makeSUT()
        let exerciseId = UUID()
        let specificDate = try #require(
            Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 15))
        )
        let progress = [
            SetProgress(status: .completedDone, currentReps: 10, weight: 60),
            SetProgress(status: .completedLess, currentReps: 8, weight: 55),
            SetProgress(status: .completedMore, currentReps: 12, weight: 65),
        ]

        sut.execute(exerciseId: exerciseId, setProgress: progress, date: specificDate)

        let saved = try #require(storage.load(for: exerciseId).first)
        #expect(saved.exerciseId == exerciseId)
        #expect(saved.date == specificDate)
        #expect(saved.setProgress.map(\.status) == [.completedDone, .completedLess, .completedMore])
    }

    @Test func executeAppendsToExistingEntries() {
        let (sut, storage) = makeSUT()
        let exerciseId = UUID()
        let existing = AnalyticsEntry(
            exerciseId: exerciseId,
            date: Date().addingTimeInterval(-86400),
            setProgress: [SetProgress(status: .completedDone, currentReps: 8, weight: 50)]
        )
        storage.save([existing], for: exerciseId)

        let progress = [SetProgress(status: .completedMore, currentReps: 12, weight: 65)]
        sut.execute(exerciseId: exerciseId, setProgress: progress)

        let saved = storage.load(for: exerciseId)
        #expect(saved.count == 2)
    }

    @Test func executeDoesNothingForEmptyProgress() {
        let (sut, storage) = makeSUT()
        let exerciseId = UUID()

        sut.execute(exerciseId: exerciseId, setProgress: [])

        #expect(storage.load(for: exerciseId).isEmpty)
    }

}
