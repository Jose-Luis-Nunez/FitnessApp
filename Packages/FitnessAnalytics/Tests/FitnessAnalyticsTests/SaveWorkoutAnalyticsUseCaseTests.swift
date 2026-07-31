import FitnessCore
import FitnessTestSupport
import Foundation
import Testing
@testable import FitnessAnalytics

@Suite("SaveWorkoutAnalyticsUseCase", .tags(.fast))
@MainActor
struct SaveWorkoutAnalyticsUseCaseTests {
    @Test func appendsEverySubmittedExerciseEntry() {
        let storage = MockAnalyticsStorage()
        let sut = SaveWorkoutAnalyticsUseCase(analyticsStorage: storage)
        let firstID = UUID()
        let secondID = UUID()

        let savedCount = sut.execute(entries: [
            makeEntry(exerciseId: firstID, reps: 8),
            makeEntry(exerciseId: secondID, reps: 12),
        ])

        #expect(savedCount == 2)
        #expect(storage.load(for: firstID).count == 1)
        #expect(storage.load(for: secondID).count == 1)
    }

    @Test func preservesExistingEntriesOnSameDay() {
        let storage = MockAnalyticsStorage()
        let sut = SaveWorkoutAnalyticsUseCase(analyticsStorage: storage)
        let exerciseID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        storage.save([makeEntry(exerciseId: exerciseID, date: date, reps: 8)], for: exerciseID)

        sut.execute(entries: [
            makeEntry(exerciseId: exerciseID, date: date, reps: 12),
        ])

        let saved = storage.load(for: exerciseID)
        #expect(saved.count == 2)
        #expect(saved.map { $0.setProgress[0].currentReps } == [8, 12])
    }

    @Test func skipsEmptyEntries() {
        let storage = MockAnalyticsStorage()
        let sut = SaveWorkoutAnalyticsUseCase(analyticsStorage: storage)
        let exerciseID = UUID()

        let savedCount = sut.execute(entries: [
            AnalyticsEntry(
                exerciseId: exerciseID,
                date: .now,
                setProgress: []
            ),
        ])

        #expect(savedCount == 0)
        #expect(storage.load(for: exerciseID).isEmpty)
    }

    @Test func reportsStorageFailure() {
        let storage = MockAnalyticsStorage()
        let existingID = UUID()
        storage.save([makeEntry(exerciseId: existingID, reps: 6)], for: existingID)
        storage.saveSucceeds = false
        let sut = SaveWorkoutAnalyticsUseCase(analyticsStorage: storage)

        let result = sut.execute(entries: [
            makeEntry(exerciseId: UUID(), reps: 8),
        ])

        #expect(result == nil)
        #expect(storage.load(for: existingID).count == 1)
        #expect(storage.savedEntries.count == 1)
    }

    private func makeEntry(
        exerciseId: UUID,
        date: Date = .now,
        reps: Int
    ) -> AnalyticsEntry {
        AnalyticsEntry(
            exerciseId: exerciseId,
            date: date,
            setProgress: [
                SetProgress(
                    status: .completedDone,
                    currentReps: reps,
                    weight: 20
                ),
            ]
        )
    }
}
