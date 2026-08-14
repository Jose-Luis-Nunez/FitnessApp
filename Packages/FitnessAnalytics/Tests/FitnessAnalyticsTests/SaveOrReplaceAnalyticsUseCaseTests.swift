import Testing
import Foundation
import FitnessCore
@testable import FitnessAnalytics
import FitnessTestSupport
@Suite("SaveOrReplaceAnalyticsUseCase", .tags(.fast))
@MainActor
struct SaveOrReplaceAnalyticsUseCaseTests {

    private func makeSUT() -> (SaveOrReplaceAnalyticsUseCase, MockAnalyticsStorage) {
        let mockStorage = MockAnalyticsStorage()
        let sut = SaveOrReplaceAnalyticsUseCase(analyticsStorage: mockStorage)
        return (sut, mockStorage)
    }

    @Test func executeReplacesExistingEntryForSameDay() {
        let (sut, storage) = makeSUT()
        let exerciseId = UUID()
        let today = Date()

        let existing = AnalyticsEntry(
            exerciseId: exerciseId,
            date: today,
            setProgress: [SetProgress(status: .completedDone, currentReps: 8, weight: 50)]
        )
        storage.save([existing], for: exerciseId)

        let newProgress = [SetProgress(status: .completedMore, currentReps: 12, weight: 65)]
        sut.execute(exerciseId: exerciseId, setProgress: newProgress, date: today)

        let saved = storage.load(for: exerciseId)
        #expect(saved.count == 1)
        #expect(saved.first?.setProgress.first?.currentReps == 12)
    }

    @Test func executeDoesNotReplaceDifferentDay() {
        let (sut, storage) = makeSUT()
        let exerciseId = UUID()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let today = Date()

        let existing = AnalyticsEntry(
            exerciseId: exerciseId,
            date: yesterday,
            setProgress: [SetProgress(status: .completedDone, currentReps: 8, weight: 50)]
        )
        storage.save([existing], for: exerciseId)

        let newProgress = [SetProgress(status: .completedDone, currentReps: 10, weight: 60)]
        sut.execute(exerciseId: exerciseId, setProgress: newProgress, date: today)

        let saved = storage.load(for: exerciseId)
        #expect(saved.count == 2)
        #expect(saved.map { $0.setProgress[0].currentReps } == [8, 10])
    }

    @Test func executeDoesNothingForEmptyProgress() {
        let (sut, storage) = makeSUT()
        let exerciseId = UUID()

        sut.execute(exerciseId: exerciseId, setProgress: [], date: Date())

        #expect(storage.load(for: exerciseId).isEmpty)
    }
}
