import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage
@Suite("Exercise & Analytics Storage Roundtrips", .tags(.integration))
@MainActor
struct ExerciseAndAnalyticsStorageTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    // MARK: - Exercise Save + Load Roundtrip

    @Test func saveAndLoadExercisesRoundtrip() {
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
        let workout = ws.workouts.first!
        let es = ExerciseStorageService(container: container)

        let exercises = [
            TestHelpers.makeExercise(name: "Bench Press", weight: 80, reps: 8, sets: 4, seatSetting: "3", category: .chest, goal: 100),
            TestHelpers.makeExercise(name: "Flyes", weight: 15, reps: 12, sets: 3, noSeats: true, category: .chest)
        ]

        es.saveForWorkout(exercises, workoutId: workout.id, category: .chest)
        let loaded = es.loadForWorkout(workoutId: workout.id, category: .chest)

        #expect(loaded.count == 2)

        let bench = loaded.first { $0.name == "Bench Press" }!
        #expect(bench.weight == 80)
        #expect(bench.reps == 8)
        #expect(bench.sets == 4)
        #expect(bench.seatSetting == "3")
        #expect(bench.category == .chest)
        #expect(bench.goal == 100)
        #expect(bench.iconName == "defaultChestIcon")

        let flyes = loaded.first { $0.name == "Flyes" }!
        #expect(flyes.noSeats == true)
        #expect(flyes.seatSetting == nil)
    }

    @Test func exerciseOrderPreserved() {
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
        let workout = ws.workouts.first!
        let es = ExerciseStorageService(container: container)

        let names = ["Third", "First", "Second"]
        let exercises = names.map { TestHelpers.makeExercise(name: $0, category: .arms) }

        es.saveForWorkout(exercises, workoutId: workout.id, category: .arms)
        let loaded = es.loadForWorkout(workoutId: workout.id, category: .arms)

        #expect(loaded.map(\.name) == names)
    }

    @Test func exercisesIsolatedBetweenCategories() {
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
        let workout = ws.workouts.first!
        let es = ExerciseStorageService(container: container)

        let armExercises = [TestHelpers.makeExercise(name: "Curl", category: .arms)]
        let chestExercises = [TestHelpers.makeExercise(name: "Bench", category: .chest)]

        es.saveForWorkout(armExercises, workoutId: workout.id, category: .arms)
        es.saveForWorkout(chestExercises, workoutId: workout.id, category: .chest)

        #expect(es.loadForWorkout(workoutId: workout.id, category: .arms).count == 1)
        #expect(es.loadForWorkout(workoutId: workout.id, category: .chest).count == 1)
        #expect(es.loadForWorkout(workoutId: workout.id, category: .legs).count == 0)
    }

    @Test func exercisesIsolatedBetweenWorkouts() throws {
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
        let workout1 = ws.workouts.first!
        let workout2 = try ws.createWorkout(name: "Workout 2")
        let es = ExerciseStorageService(container: container)

        es.saveForWorkout(
            [TestHelpers.makeExercise(name: "Curl", category: .arms)],
            workoutId: workout1.id,
            category: .arms
        )

        #expect(es.loadForWorkout(workoutId: workout1.id, category: .arms).count == 1)
        #expect(es.loadForWorkout(workoutId: workout2.id, category: .arms).count == 0)
    }

    @Test func saveOverwritesPreviousExercises() {
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
        let workout = ws.workouts.first!
        let es = ExerciseStorageService(container: container)

        es.saveForWorkout(
            [TestHelpers.makeExercise(name: "Old", category: .chest)],
            workoutId: workout.id,
            category: .chest
        )
        #expect(es.loadForWorkout(workoutId: workout.id, category: .chest).count == 1)

        es.saveForWorkout(
            [
                TestHelpers.makeExercise(name: "New1", category: .chest),
                TestHelpers.makeExercise(name: "New2", category: .chest)
            ],
            workoutId: workout.id,
            category: .chest
        )

        let loaded = es.loadForWorkout(workoutId: workout.id, category: .chest)
        #expect(loaded.count == 2)
        #expect(!loaded.contains { $0.name == "Old" })
    }

    // MARK: - Analytics Save + Load Roundtrip

    @Test func saveAndLoadAnalyticsRoundtrip() {
        let as_ = AnalyticsStorageService(container: container)
        let exerciseId = UUID()

        let entries = [
            TestHelpers.makeAnalyticsEntry(
                exerciseId: exerciseId,
                setProgress: [
                    SetProgress(status: .completedDone, currentReps: 10, weight: 60),
                    SetProgress(status: .completedMore, currentReps: 12, weight: 65),
                    SetProgress(status: .completedLess, currentReps: 8, weight: 55)
                ]
            )
        ]

        as_.save(entries, for: exerciseId)
        let loaded = as_.load(for: exerciseId)

        #expect(loaded.count == 1)
        #expect(loaded.first!.exerciseId == exerciseId)
        #expect(loaded.first!.setProgress.count == 3)

        let progress = loaded.first!.setProgress
        #expect(progress[0].status == .completedDone)
        #expect(progress[0].weight == 60)
        #expect(progress[1].status == .completedMore)
        #expect(progress[1].currentReps == 12)
        #expect(progress[2].status == .completedLess)
        #expect(progress[2].weight == 55)
    }

    @Test func analyticsSetProgressOrderPreserved() {
        let as_ = AnalyticsStorageService(container: container)
        let exerciseId = UUID()

        let progress: [SetProgress] = (1...5).map {
            SetProgress(status: .completedDone, currentReps: $0 * 2, weight: Double($0) * 10)
        }
        let entries = [AnalyticsEntry(exerciseId: exerciseId, date: Date(), setProgress: progress)]
        as_.save(entries, for: exerciseId)

        let loaded = as_.load(for: exerciseId).first!
        for (i, sp) in loaded.setProgress.enumerated() {
            #expect(sp.currentReps == (i + 1) * 2)
            #expect(sp.weight == Double(i + 1) * 10)
        }
    }

    @Test func analyticsSaveOverwritesPrevious() {
        let as_ = AnalyticsStorageService(container: container)
        let exerciseId = UUID()

        let first = [TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId)]
        as_.save(first, for: exerciseId)
        #expect(as_.load(for: exerciseId).count == 1)

        let second = [
            TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId),
            TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId)
        ]
        as_.save(second, for: exerciseId)
        #expect(as_.load(for: exerciseId).count == 2)
    }

    @Test func analyticsIsolatedBetweenExercises() {
        let as_ = AnalyticsStorageService(container: container)
        let id1 = UUID()
        let id2 = UUID()

        as_.save([TestHelpers.makeAnalyticsEntry(exerciseId: id1)], for: id1)
        as_.save([TestHelpers.makeAnalyticsEntry(exerciseId: id2)], for: id2)

        #expect(as_.load(for: id1).count == 1)
        #expect(as_.load(for: id2).count == 1)
        #expect(as_.load(for: UUID()).count == 0)
    }

    // MARK: - Cascade Delete

    @Test func deleteWorkoutCascadesExercises() throws {
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
        let workout = try ws.createWorkout(name: "To Delete")
        let es = ExerciseStorageService(container: container)

        es.saveForWorkout(
            [TestHelpers.makeExercise(name: "Curl", category: .arms)],
            workoutId: workout.id,
            category: .arms
        )
        #expect(es.loadForWorkout(workoutId: workout.id, category: .arms).count == 1)

        ws.deleteWorkout(workout)

        #expect(es.loadForWorkout(workoutId: workout.id, category: .arms).count == 0)
    }

    // MARK: - Empty State

    @Test func loadFromEmptyDatabaseReturnsEmpty() {
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
        let es = ExerciseStorageService(container: container)
        let as_ = AnalyticsStorageService(container: container)

        #expect(es.loadForWorkout(workoutId: ws.workouts.first!.id, category: .arms).isEmpty)
        #expect(as_.load(for: UUID()).isEmpty)
    }
}
