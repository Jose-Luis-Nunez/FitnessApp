import Testing
import Foundation
import FitnessCore
@testable import FitnessAnalytics
import FitnessTestSupport
@Suite("DeleteAnalyticsSetUseCase", .tags(.fast))
@MainActor
struct DeleteAnalyticsSetUseCaseTests {
    @Test func deletesBothSidesOfOneLogicalSet() {
        let exerciseId = UUID()
        let entryId = UUID()
        let progress = (0..<2).flatMap { logicalIndex in
            ExerciseSide.allCases.map {
                SetProgress(
                    status: .completedDone,
                    currentReps: 12,
                    weight: 20,
                    side: $0,
                    logicalSetIndex: logicalIndex
                )
            }
        }
        let storage = MockAnalyticsStorage()
        storage.save([
            AnalyticsEntry(
                id: entryId,
                exerciseId: exerciseId,
                date: .now,
                setProgress: progress
            )
        ], for: exerciseId)
        let sut = DeleteAnalyticsSetUseCase(
            analyticsStorage: storage,
            exerciseStorage: MockExerciseStorage(),
            workoutStorage: MockWorkoutStorage()
        )

        sut.execute(
            exerciseId: exerciseId,
            entryId: entryId,
            logicalSetIndex: 0
        )

        let remaining = storage.load(for: exerciseId).first?.setProgress
        #expect(remaining?.count == 2)
        #expect(remaining?.allSatisfy { $0.logicalSetIndex == 1 } == true)
    }

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
        #expect(exerciseStorage.updatedExercises.map(\.id) == [exerciseId])
        #expect(exerciseStorage.saveForWorkoutCallCount == 0)
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
