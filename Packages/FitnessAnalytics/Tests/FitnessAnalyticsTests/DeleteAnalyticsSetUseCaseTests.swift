import Testing
import Foundation
import FitnessCore
@testable import FitnessAnalytics
import FitnessTestSupport
@Suite("DeleteAnalyticsSetUseCase", .tags(.fast))
@MainActor
struct DeleteAnalyticsSetUseCaseTests {

    private func makeSUT() -> (DeleteAnalyticsSetUseCase, MockAnalyticsStorage, MockExerciseStorage, MockWorkoutStorage) {
        let mockAnalytics = MockAnalyticsStorage()
        let mockExercise = MockExerciseStorage()
        let mockWorkout = MockWorkoutStorage()
        let sut = DeleteAnalyticsSetUseCase(
            analyticsStorage: mockAnalytics,
            exerciseStorage: mockExercise,
            workoutStorage: mockWorkout
        )
        return (sut, mockAnalytics, mockExercise, mockWorkout)
    }

    @Test func deleteSetRemovesSetFromEntry() {
        let (sut, storage, _, _) = makeSUT()
        let exerciseId = UUID()
        let entry = AnalyticsEntry(
            exerciseId: exerciseId,
            date: Date(),
            setProgress: [
                SetProgress(status: .completedDone, currentReps: 10, weight: 60),
                SetProgress(status: .completedMore, currentReps: 12, weight: 65)
            ]
        )
        storage.save([entry], for: exerciseId)

        sut.execute(exerciseId: exerciseId, entryId: entry.id, setIndex: 0)

        let saved = storage.load(for: exerciseId)
        #expect(saved.count == 1)
        #expect(saved.first?.setProgress.count == 1)
        #expect(saved.first?.setProgress.first?.currentReps == 12)
    }

    @Test func deleteLastSetRemovesEntireEntry() {
        let (sut, storage, _, _) = makeSUT()
        let exerciseId = UUID()
        let entry = AnalyticsEntry(
            exerciseId: exerciseId,
            date: Date(),
            setProgress: [SetProgress(status: .completedDone, currentReps: 10, weight: 60)]
        )
        storage.save([entry], for: exerciseId)

        sut.execute(exerciseId: exerciseId, entryId: entry.id, setIndex: 0)

        #expect(storage.load(for: exerciseId).isEmpty)
    }

    @Test func deleteAllEntriesUpdatesExerciseCompletion() {
        let (sut, analyticsStorage, exerciseStorage, workoutStorage) = makeSUT()
        let exerciseId = UUID()
        let workout = Workout(name: "Test")
        workoutStorage.currentWorkout = workout
        workoutStorage.workouts = [workout]

        let exercise = FitnessTestSupport.makeExercise(id: exerciseId, name: "Curl", isCompleted: true, category: .arms)
        exerciseStorage.exercisesByCategory[.arms] = [exercise]

        let entry = AnalyticsEntry(
            exerciseId: exerciseId,
            date: Date(),
            setProgress: [SetProgress(status: .completedDone, currentReps: 10, weight: 60)]
        )
        analyticsStorage.save([entry], for: exerciseId)

        sut.execute(exerciseId: exerciseId, entryId: entry.id, setIndex: 0)

        let exercises = exerciseStorage.loadForWorkout(workoutId: workout.id, category: .arms)
        #expect(exercises.first?.isCompleted == false)
    }

    @Test func deleteDoesNothingForInvalidEntryId() {
        let (sut, storage, _, _) = makeSUT()
        let exerciseId = UUID()
        let entry = AnalyticsEntry(
            exerciseId: exerciseId,
            date: Date(),
            setProgress: [SetProgress(status: .completedDone, currentReps: 10, weight: 60)]
        )
        storage.save([entry], for: exerciseId)

        sut.execute(exerciseId: exerciseId, entryId: UUID(), setIndex: 0)

        #expect(storage.load(for: exerciseId).count == 1)
    }

    @Test func deleteDoesNothingForInvalidSetIndex() {
        let (sut, storage, _, _) = makeSUT()
        let exerciseId = UUID()
        let entry = AnalyticsEntry(
            exerciseId: exerciseId,
            date: Date(),
            setProgress: [SetProgress(status: .completedDone, currentReps: 10, weight: 60)]
        )
        storage.save([entry], for: exerciseId)

        sut.execute(exerciseId: exerciseId, entryId: entry.id, setIndex: 5)

        #expect(storage.load(for: exerciseId).first?.setProgress.count == 1)
    }
}
