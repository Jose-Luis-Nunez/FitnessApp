import Testing
import Foundation
@testable import FitnessSchedule
@testable import FitnessAnalytics
import FitnessCore
import FitnessTestSupport

// MARK: - Helpers

@MainActor
private func date(_ offset: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date()))!
}

@MainActor
private func makeEntry(
    exerciseId: UUID,
    date: Date,
    sets: [(weight: Double, reps: Int)]
) -> AnalyticsEntry {
    AnalyticsEntry(
        exerciseId: exerciseId,
        date: date,
        setProgress: sets.map {
            SetProgress(status: .completedDone, currentReps: $0.reps, weight: $0.weight)
        }
    )
}

/// Creates mocks and returns a fully-wired `TotalAnalyticsViewModel` using constructor-DI.
@MainActor
private func setupMocks(
    exercises: [Exercise] = [],
    entries: [UUID: [AnalyticsEntry]] = [:]
) -> (TotalAnalyticsViewModel, MockWorkoutStorage, MockExerciseStorage, MockAnalyticsStorage) {
    let analyticsStorage = MockAnalyticsStorage()
    let exerciseStorage = MockExerciseStorage()
    let workoutStorage = MockWorkoutStorage()

    let workout = Workout(name: "Test", selectedCategories: Set(MuscleCategoryGroup.allCases))
    workoutStorage.currentWorkout = workout
    workoutStorage.workouts = [workout]

    for exercise in exercises {
        var existing = exerciseStorage.exercisesByCategory[exercise.category] ?? []
        existing.append(exercise)
        exerciseStorage.exercisesByCategory[exercise.category] = existing
    }

    for (id, entryList) in entries {
        analyticsStorage.save(entryList, for: id)
    }

    let totalStorage = MockTotalAnalyticsStorage(
        analyticsStorage: analyticsStorage,
        exerciseStorage: exerciseStorage,
        workoutStorage: workoutStorage
    )

    let vm = TotalAnalyticsViewModel(
        totalAnalyticsStorage: totalStorage,
        workoutStorage: workoutStorage,
        exerciseStorage: exerciseStorage
    )

    return (vm, workoutStorage, exerciseStorage, analyticsStorage)
}

/// Creates 3 exercises and entries on each given day offset, so every day qualifies as a training day (>=3 exercises).
@MainActor
private func setupTrainingDays(
    offsets: [Int]
) -> (exercises: [Exercise], vm: TotalAnalyticsViewModel, workoutStorage: MockWorkoutStorage) {
    let ex1 = makeExercise(name: "Ex1", category: .arms)
    let ex2 = makeExercise(name: "Ex2", category: .chest)
    let ex3 = makeExercise(name: "Ex3", category: .back)

    var entries1: [AnalyticsEntry] = []
    var entries2: [AnalyticsEntry] = []
    var entries3: [AnalyticsEntry] = []

    for offset in offsets {
        let d = date(offset)
        entries1.append(makeEntry(exerciseId: ex1.id, date: d, sets: [(20, 10)]))
        entries2.append(makeEntry(exerciseId: ex2.id, date: d, sets: [(40, 10)]))
        entries3.append(makeEntry(exerciseId: ex3.id, date: d, sets: [(30, 10)]))
    }

    let (vm, workoutStorage, _, _) = setupMocks(
        exercises: [ex1, ex2, ex3],
        entries: [
            ex1.id: entries1,
            ex2.id: entries2,
            ex3.id: entries3,
        ]
    )

    return ([ex1, ex2, ex3], vm, workoutStorage)
}

// MARK: - reloadData

@Suite("reloadData", .tags(.fast))
@MainActor
struct ReloadDataTests {

    @Test func populatesTrainingDaySetAndDatesWithData() {
        let (_, analyticsVM, _) = setupTrainingDays(offsets: [-2, 0])
        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)
        vm.reloadData()

        #expect(!vm.trainingDaySet.isEmpty)
        #expect(!vm.datesWithData.isEmpty)
    }

    @Test func emptyWhenNoData() {
        let (analyticsVM, _, _, _) = setupMocks()
        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)
        vm.reloadData()

        #expect(vm.trainingDaySet.isEmpty)
        #expect(vm.datesWithData.isEmpty)
    }
}

// MARK: - streakData

@Suite("streakData", .tags(.fast))
@MainActor
struct StreakDataTests {

    @Test func returnsZeroStreakWhenNoData() {
        let (analyticsVM, _, _, _) = setupMocks()
        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)
        let streak = vm.streakData()

        #expect(streak.current == 0)
        #expect(streak.longest == 0)
    }

    @Test func detectsConsecutiveDayStreak() {
        let (_, analyticsVM, _) = setupTrainingDays(offsets: [-2, -1, 0])
        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)
        let streak = vm.streakData()

        #expect(streak.current == 3)
        #expect(streak.longest == 3)
    }

    @Test func breaksStreakOnGap() {
        let (_, analyticsVM, _) = setupTrainingDays(offsets: [-5, -4, -1, 0])
        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)
        let streak = vm.streakData()

        #expect(streak.current == 2)
        #expect(streak.longest == 2)
    }
}

// MARK: - weekSummary

@Suite("weekSummary", .tags(.fast))
@MainActor
struct WeekSummaryTests {

    @Test func returnsSevenDays() {
        let (analyticsVM, _, _, _) = setupMocks()
        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)
        let summary = vm.weekSummary(for: Date())

        #expect(summary.days.count == 7)
    }

    @Test func usesGermanWeekdayLabels() {
        let (analyticsVM, _, _, _) = setupMocks()
        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)
        let summary = vm.weekSummary(for: Date())
        let labels = summary.days.map(\.label)

        #expect(labels == ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"])
    }

    @Test func countsTrainingDaysInWeek() {
        let (_, analyticsVM, _) = setupTrainingDays(offsets: [0])
        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)
        let summary = vm.weekSummary(for: date(0))

        #expect(summary.trainingDayCount >= 0)
        #expect(summary.totalExercises >= 0)
    }
}

// MARK: - dayDetail

@Suite("dayDetail", .tags(.fast))
@MainActor
struct DayDetailTests {

    @Test func returnsNilWhenNoWorkout() {
        let (analyticsVM, workoutStorage, _, _) = setupMocks()
        workoutStorage.currentWorkout = nil

        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)
        #expect(vm.dayDetail(for: date(0)) == nil)
    }

    @Test func returnsDetailForDayWithData() {
        let ex = makeExercise(name: "Curl", category: .arms)
        let today = date(0)
        let (analyticsVM, _, _, _) = setupMocks(
            exercises: [ex],
            entries: [ex.id: [makeEntry(exerciseId: ex.id, date: today, sets: [(20, 10)])]]
        )

        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)
        let detail = vm.dayDetail(for: today)

        #expect(detail != nil)
        #expect(detail!.categories.contains { $0.category == .arms })
    }
}

// MARK: - exerciseCountForDay

@Suite("exerciseCountForDay", .tags(.fast))
@MainActor
struct ExerciseCountForDayTests {

    @Test func returnsZeroForDayWithoutData() {
        let (analyticsVM, _, _, _) = setupMocks()
        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)

        #expect(vm.exerciseCountForDay(date(0)) == 0)
    }

    @Test func countsDistinctExercises() {
        let ex1 = makeExercise(name: "Curl", category: .arms)
        let ex2 = makeExercise(name: "Bench", category: .chest)
        let today = date(0)

        let (analyticsVM, _, _, _) = setupMocks(
            exercises: [ex1, ex2],
            entries: [
                ex1.id: [makeEntry(exerciseId: ex1.id, date: today, sets: [(20, 10)])],
                ex2.id: [makeEntry(exerciseId: ex2.id, date: today, sets: [(60, 10)])],
            ]
        )

        let vm = ScheduleViewModel(totalAnalyticsVM: analyticsVM)
        #expect(vm.exerciseCountForDay(today) == 2)
    }
}
