import Foundation
import Testing
@testable import FitnessCore

@Suite("Analytics batch protocols and workout snapshots")
@MainActor
struct TotalAnalyticsStoringTests {
    @Test func analyticsBatchDefaultNormalizesPublicDuplicateInput() throws {
        let id = UUID()
        let storage = LegacyAnalyticsStorage(
            histories: [id: [AnalyticsEntry(exerciseId: id, date: .now, setProgress: [])]]
        )

        let result = try storage.loadBatch(for: [id, id])

        #expect(result.count == 1)
        #expect(result[id]?.first?.exerciseId == id)
        #expect(storage.loadedIds == [id])
    }

    @Test func exerciseWorkoutDefaultForwardsWorkoutIdAcrossCategories() throws {
        let workoutId = UUID()
        let exercise = Exercise(
            name: "Curl",
            weight: 20,
            reps: 10,
            sets: 3,
            iconName: "defaultArmsIcon",
            category: .arms
        )
        let storage = LegacyExerciseStorage(exercise: exercise)

        let result = try storage.loadWorkoutExercises(for: workoutId)

        #expect(result.map(\.id) == [exercise.id])
        #expect(storage.requestedWorkoutIds.count == MuscleCategoryGroup.allCases.count)
        #expect(storage.requestedWorkoutIds.allSatisfy { $0 == workoutId })
    }

    @Test func snapshotUsesStableTieBreakersForEqualDates() throws {
        let workoutId = UUID()
        let exerciseA = Exercise(
            id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
            name: "A",
            weight: 20,
            reps: 10,
            sets: 3,
            iconName: "defaultArmsIcon",
            category: .arms
        )
        let exerciseB = Exercise(
            id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")),
            name: "B",
            weight: 20,
            reps: 10,
            sets: 3,
            iconName: "defaultChestIcon",
            category: .chest
        )
        let sharedDate = Date(timeIntervalSince1970: 100)
        let entryForA = AnalyticsEntry(
            id: try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000002")),
            exerciseId: exerciseA.id,
            date: sharedDate,
            setProgress: []
        )
        let laterIdForB = AnalyticsEntry(
            id: try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000002")),
            exerciseId: exerciseB.id,
            date: sharedDate,
            setProgress: []
        )
        let earlierIdForB = AnalyticsEntry(
            id: try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000001")),
            exerciseId: exerciseB.id,
            date: sharedDate,
            setProgress: []
        )

        let snapshot = WorkoutAnalyticsSnapshot(
            workoutId: workoutId,
            exercises: [exerciseA, exerciseB],
            entriesByExerciseId: [
                exerciseB.id: [laterIdForB, earlierIdForB],
                exerciseA.id: [entryForA],
            ]
        )

        #expect(snapshot.entries.map(\.id) == [
            entryForA.id,
            earlierIdForB.id,
            laterIdForB.id,
        ])
    }
}

@MainActor
private final class LegacyAnalyticsStorage: AnalyticsStoring {
    let histories: [UUID: [AnalyticsEntry]]
    private(set) var loadedIds: [UUID] = []

    init(histories: [UUID: [AnalyticsEntry]]) {
        self.histories = histories
    }

    func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {}

    func load(for exerciseId: UUID) -> [AnalyticsEntry] {
        loadedIds.append(exerciseId)
        return histories[exerciseId] ?? []
    }
}

@MainActor
private final class LegacyExerciseStorage: ExerciseStoring {
    let exercise: Exercise
    private(set) var requestedWorkoutIds: [UUID] = []

    init(exercise: Exercise) {
        self.exercise = exercise
    }

    func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise] {
        requestedWorkoutIds.append(workoutId)
        return category == exercise.category ? [exercise] : []
    }

    func exerciseCountsByWorkout() -> [UUID: Int] { [:] }
    func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {}
    func updateExercise(_ exercise: Exercise) {}
}
