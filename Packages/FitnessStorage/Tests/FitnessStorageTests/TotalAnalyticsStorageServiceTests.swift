import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("TotalAnalyticsStorageService", .tags(.integration))
@MainActor
struct TotalAnalyticsStorageServiceTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func makeSUT() -> (TotalAnalyticsStorageService, WorkoutStorageService, ExerciseStorageService, AnalyticsStorageService) {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let es = ExerciseStorageService(container: container)
        let as_ = AnalyticsStorageService(container: container)
        let ws = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: es, analyticsStorage: as_)

        let sut = TotalAnalyticsStorageService(
            analyticsStorage: as_,
            exerciseStorage: es,
            workoutStorage: ws
        )
        return (sut, ws, es, as_)
    }

    // MARK: - loadAnalytics(for exerciseId:)

    @Test func loadAnalyticsForExerciseReturnsEntries() {
        let (sut, _, _, as_) = makeSUT()
        let exerciseId = UUID()
        let entry = TestHelpers.makeAnalyticsEntry(exerciseId: exerciseId)
        as_.save([entry], for: exerciseId)

        let loaded = sut.loadAnalytics(for: exerciseId)
        #expect(loaded.count == 1)
        #expect(loaded.first?.exerciseId == exerciseId)
    }

    @Test func loadAnalyticsForUnknownExerciseReturnsEmpty() {
        let (sut, _, _, _) = makeSUT()
        #expect(sut.loadAnalytics(for: UUID()).isEmpty)
    }

    // MARK: - loadAllAnalytics()

    @Test func loadAllAnalyticsReturnsEntriesForCurrentWorkout() {
        let (sut, ws, es, as_) = makeSUT()
        let workout = ws.workouts.first!

        let exercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        es.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        let entry = TestHelpers.makeAnalyticsEntry(exerciseId: exercise.id)
        as_.save([entry], for: exercise.id)

        let all = sut.loadAllAnalytics()
        #expect(all.count == 1)
    }

    @Test func loadAllAnalyticsReturnsEmptyWhenNoCurrentWorkout() {
        let ws = MockWorkoutStorage()
        let es = MockExerciseStorage()
        let as_ = StubAnalyticsStorage()

        let sut = TotalAnalyticsStorageService(
            analyticsStorage: as_,
            exerciseStorage: es,
            workoutStorage: ws
        )
        #expect(sut.loadAllAnalytics().isEmpty)
    }

    @Test func loadAllAnalyticsSortedByDateDescending() {
        let (sut, ws, es, as_) = makeSUT()
        let workout = ws.workouts.first!
        let calendar = Calendar.current

        let exercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        es.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        let oldDate = calendar.date(byAdding: .day, value: -5, to: Date())!
        let newDate = Date()

        let entries = [
            TestHelpers.makeAnalyticsEntry(exerciseId: exercise.id, date: oldDate),
            TestHelpers.makeAnalyticsEntry(exerciseId: exercise.id, date: newDate)
        ]
        as_.save(entries, for: exercise.id)

        let all = sut.loadAllAnalytics()
        #expect(all.count == 2)
        #expect(all.first!.date >= all.last!.date)
    }

    // MARK: - loadAllAnalytics(for workoutId:)

    @Test func loadAllAnalyticsForSpecificWorkout() throws {
        let (sut, ws, es, as_) = makeSUT()
        let workout1 = ws.workouts.first!
        let workout2 = try ws.createWorkout(name: "Workout 2")

        let ex1 = TestHelpers.makeExercise(name: "Curl", category: .arms)
        let ex2 = TestHelpers.makeExercise(name: "Bench", category: .chest)
        es.saveForWorkout([ex1], workoutId: workout1.id, category: .arms)
        es.saveForWorkout([ex2], workoutId: workout2.id, category: .chest)

        as_.save([TestHelpers.makeAnalyticsEntry(exerciseId: ex1.id)], for: ex1.id)
        as_.save([TestHelpers.makeAnalyticsEntry(exerciseId: ex2.id)], for: ex2.id)

        let forWorkout1 = sut.loadAllAnalytics(for: workout1.id)
        let forWorkout2 = sut.loadAllAnalytics(for: workout2.id)

        #expect(forWorkout1.count == 1)
        #expect(forWorkout2.count == 1)
        #expect(forWorkout1.first?.exerciseId == ex1.id)
        #expect(forWorkout2.first?.exerciseId == ex2.id)
    }

    // MARK: - loadAllAnalytics(for date:)

    @Test func loadAllAnalyticsForDateFiltersCorrectly() {
        let (sut, ws, es, as_) = makeSUT()
        let workout = ws.workouts.first!
        let calendar = Calendar.current

        let exercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        es.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        as_.save([
            TestHelpers.makeAnalyticsEntry(exerciseId: exercise.id, date: today),
            TestHelpers.makeAnalyticsEntry(exerciseId: exercise.id, date: yesterday)
        ], for: exercise.id)

        let todayEntries = sut.loadAllAnalytics(for: today)
        #expect(todayEntries.count == 1)
        #expect(calendar.isDate(todayEntries.first!.date, inSameDayAs: today))
    }

    // MARK: - getAllExercisesWithAnalytics

    @Test func getAllExercisesWithAnalyticsReturnsOnlyExercisesHavingEntries() {
        let (sut, ws, es, as_) = makeSUT()
        let workout = ws.workouts.first!

        let withAnalytics = TestHelpers.makeExercise(name: "Curl", category: .arms)
        let withoutAnalytics = TestHelpers.makeExercise(name: "Bench", category: .chest)

        es.saveForWorkout([withAnalytics], workoutId: workout.id, category: .arms)
        es.saveForWorkout([withoutAnalytics], workoutId: workout.id, category: .chest)

        as_.save([TestHelpers.makeAnalyticsEntry(exerciseId: withAnalytics.id)], for: withAnalytics.id)

        let result = sut.getAllExercisesWithAnalytics()
        #expect(result.count == 1)
        #expect(result.first?.name == "Curl")
    }

    @Test func getAllExercisesWithAnalyticsReturnsEmptyWhenNoAnalytics() {
        let (sut, ws, es, _) = makeSUT()
        let workout = ws.workouts.first!

        es.saveForWorkout(
            [TestHelpers.makeExercise(name: "Curl", category: .arms)],
            workoutId: workout.id, category: .arms
        )

        #expect(sut.getAllExercisesWithAnalytics().isEmpty)
    }

    @Test func getAllExercisesWithAnalyticsForSpecificWorkout() throws {
        let (sut, ws, es, as_) = makeSUT()
        let workout1 = ws.workouts.first!
        let workout2 = try ws.createWorkout(name: "Workout 2")

        let ex1 = TestHelpers.makeExercise(name: "Curl", category: .arms)
        let ex2 = TestHelpers.makeExercise(name: "Bench", category: .arms)

        es.saveForWorkout([ex1], workoutId: workout1.id, category: .arms)
        es.saveForWorkout([ex2], workoutId: workout2.id, category: .arms)

        as_.save([TestHelpers.makeAnalyticsEntry(exerciseId: ex1.id)], for: ex1.id)
        as_.save([TestHelpers.makeAnalyticsEntry(exerciseId: ex2.id)], for: ex2.id)

        let result1 = sut.getAllExercisesWithAnalytics(for: workout1.id)
        let result2 = sut.getAllExercisesWithAnalytics(for: workout2.id)

        #expect(result1.count == 1)
        #expect(result1.first?.name == "Curl")
        #expect(result2.count == 1)
        #expect(result2.first?.name == "Bench")
    }

    // MARK: - Cross-Category

    @Test func loadAllAnalyticsSpansAllCategories() {
        let (sut, ws, es, as_) = makeSUT()
        let workout = ws.workouts.first!

        let armEx = TestHelpers.makeExercise(name: "Curl", category: .arms)
        let chestEx = TestHelpers.makeExercise(name: "Bench", category: .chest)

        es.saveForWorkout([armEx], workoutId: workout.id, category: .arms)
        es.saveForWorkout([chestEx], workoutId: workout.id, category: .chest)

        as_.save([TestHelpers.makeAnalyticsEntry(exerciseId: armEx.id)], for: armEx.id)
        as_.save([TestHelpers.makeAnalyticsEntry(exerciseId: chestEx.id)], for: chestEx.id)

        let all = sut.loadAllAnalytics()
        #expect(all.count == 2)
    }
}
