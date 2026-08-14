import FitnessCore
import Foundation
import Testing
@testable import FitnessAnalytics

@Suite("SaveWorkoutAnalyticsUseCase", .tags(.fast))
@MainActor
struct SaveWorkoutAnalyticsUseCaseTests {
    @Test func appendsEverySubmittedExerciseEntry() {
        let storage = RecordingBatchStorage()
        let sut = SaveWorkoutAnalyticsUseCase(batchStorage: storage)
        let firstID = UUID()
        let secondID = UUID()

        let savedCount = sut.execute(entries: [
            makeEntry(exerciseId: firstID, reps: 8),
            makeEntry(exerciseId: secondID, reps: 12),
        ])

        #expect(savedCount == 2)
        #expect(storage.batches.count == 1)
        #expect(storage.batches[0].map(\.exerciseId) == [firstID, secondID])
    }

    @Test func skipsEmptyEntries() {
        let storage = RecordingBatchStorage()
        let sut = SaveWorkoutAnalyticsUseCase(batchStorage: storage)
        let exerciseID = UUID()

        let savedCount = sut.execute(entries: [
            AnalyticsEntry(
                exerciseId: exerciseID,
                date: .now,
                setProgress: []
            ),
        ])

        #expect(savedCount == 0)
        #expect(storage.batches.count == 1)
        #expect(storage.batches.first?.isEmpty == true)
    }

    @Test func reportsStorageFailure() {
        let storage = RecordingBatchStorage(result: false)
        let sut = SaveWorkoutAnalyticsUseCase(batchStorage: storage)
        let entry = makeEntry(exerciseId: UUID(), reps: 8)

        let result = sut.execute(entries: [entry])

        #expect(result == nil)
        #expect(storage.batches.map { $0.map(\.id) } == [[entry.id]])
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

@MainActor
private final class RecordingBatchStorage: WorkoutAnalyticsBatchStoring {
    private let result: Bool
    private(set) var batches: [[AnalyticsEntry]] = []

    init(result: Bool = true) {
        self.result = result
    }

    func appendWorkoutAnalytics(_ entries: [AnalyticsEntry]) -> Bool {
        batches.append(entries)
        return result
    }
}
