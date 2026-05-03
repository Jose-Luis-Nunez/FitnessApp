import Testing
import Foundation
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

// MARK: - getCategoryProgressData

@Suite("getCategoryProgressData", .tags(.fast))
@MainActor
struct GetCategoryProgressDataTests {

    @Test func returnsEmptyCategoriesWhenNoExercises() {
        let (vm, _, _, _) = setupMocks()
        let result = vm.getCategoryProgressData()

        #expect(result.count == 5)
        #expect(result.allSatisfy { $0.exercises.isEmpty })
    }

    @Test func returnsProgressForExerciseWithEntries() {
        let exerciseId = UUID()
        let exercise = makeExercise(id: exerciseId, name: "Curl", weight: 20, category: .arms)
        let (vm, _, _, _) = setupMocks(
            exercises: [exercise],
            entries: [exerciseId: [
                makeEntry(exerciseId: exerciseId, date: date(-2), sets: [(20, 10)]),
                makeEntry(exerciseId: exerciseId, date: date(0), sets: [(25, 10)]),
            ]]
        )
        let result = vm.getCategoryProgressData()
        let armsData = result.first { $0.category == .arms }!

        #expect(armsData.exercises.count == 1)
        #expect(armsData.exercises[0].initialWeight == 20)
        #expect(armsData.exercises[0].currentWeight == 25)
        #expect(armsData.exercises[0].sessionsCount == 2)
    }

    @Test func excludesExercisesWithoutEntries() {
        let exercise = makeExercise(name: "Curl", category: .arms)
        let (vm, _, _, _) = setupMocks(exercises: [exercise])
        let armsData = vm.getCategoryProgressData().first { $0.category == .arms }!

        #expect(armsData.exercises.isEmpty)
    }

    @Test func tracksWeightIncrements() {
        let id = UUID()
        let exercise = makeExercise(id: id, category: .chest)
        let (vm, _, _, _) = setupMocks(
            exercises: [exercise],
            entries: [id: [
                makeEntry(exerciseId: id, date: date(-3), sets: [(40, 10)]),
                makeEntry(exerciseId: id, date: date(-2), sets: [(45, 10)]),
                makeEntry(exerciseId: id, date: date(-1), sets: [(45, 10)]),
                makeEntry(exerciseId: id, date: date(0), sets: [(50, 10)]),
            ]]
        )
        let chestData = vm.getCategoryProgressData().first { $0.category == .chest }!

        #expect(chestData.exercises[0].weightIncrements == 2)
        #expect(chestData.exercises[0].totalWeightGains == 10.0)
    }
}

// MARK: - getMostTrainedCategory

@Suite("getMostTrainedCategory", .tags(.fast))
@MainActor
struct GetMostTrainedCategoryTests {

    @Test func returnsDefaultWhenNoData() {
        let (vm, _, _, _) = setupMocks()
        let result = vm.getMostTrainedCategory()

        #expect(result.count == 0)
    }

    @Test func returnsCategoryWithMostExercises() {
        let armEx1 = makeExercise(name: "Curl", category: .arms)
        let armEx2 = makeExercise(name: "Hammer Curl", category: .arms)
        let chestEx = makeExercise(name: "Bench", category: .chest)

        let (vm, _, _, _) = setupMocks(
            exercises: [armEx1, armEx2, chestEx],
            entries: [
                armEx1.id: [makeEntry(exerciseId: armEx1.id, date: date(0), sets: [(20, 10)])],
                armEx2.id: [makeEntry(exerciseId: armEx2.id, date: date(0), sets: [(15, 10)])],
                chestEx.id: [makeEntry(exerciseId: chestEx.id, date: date(0), sets: [(60, 10)])],
            ]
        )
        let result = vm.getMostTrainedCategory()

        #expect(result.category == .arms)
        #expect(result.count == 2)
    }
}

// MARK: - getLeastTrainedCategory

@Suite("getLeastTrainedCategory", .tags(.fast))
@MainActor
struct GetLeastTrainedCategoryTests {

    @Test func returnsCategoryWithFewestExercises() {
        let armEx1 = makeExercise(name: "Curl", category: .arms)
        let armEx2 = makeExercise(name: "Hammer Curl", category: .arms)
        let chestEx = makeExercise(name: "Bench", category: .chest)

        let (vm, _, _, _) = setupMocks(
            exercises: [armEx1, armEx2, chestEx],
            entries: [
                armEx1.id: [makeEntry(exerciseId: armEx1.id, date: date(0), sets: [(20, 10)])],
                armEx2.id: [makeEntry(exerciseId: armEx2.id, date: date(0), sets: [(15, 10)])],
                chestEx.id: [makeEntry(exerciseId: chestEx.id, date: date(0), sets: [(60, 10)])],
            ]
        )
        let result = vm.getLeastTrainedCategory()

        #expect(result.category == .chest)
        #expect(result.count == 1)
    }
}

// MARK: - getTrainingDays

@Suite("getTrainingDays", .tags(.fast))
@MainActor
struct GetTrainingDaysTests {

    @Test func returnsEmptyWhenNoData() {
        let (vm, _, _, _) = setupMocks()

        #expect(vm.getTrainingDays().isEmpty)
    }

    @Test func requiresAtLeast3ExercisesPerDay() {
        let ex1 = makeExercise(name: "Ex1", category: .arms)
        let ex2 = makeExercise(name: "Ex2", category: .chest)
        let today = date(0)

        let (vm, _, _, _) = setupMocks(
            exercises: [ex1, ex2],
            entries: [
                ex1.id: [makeEntry(exerciseId: ex1.id, date: today, sets: [(20, 10)])],
                ex2.id: [makeEntry(exerciseId: ex2.id, date: today, sets: [(40, 10)])],
            ]
        )
        #expect(vm.getTrainingDays().isEmpty)
    }

    @Test func countsTrainingDayWith3OrMoreExercises() {
        let ex1 = makeExercise(name: "Ex1", category: .arms)
        let ex2 = makeExercise(name: "Ex2", category: .chest)
        let ex3 = makeExercise(name: "Ex3", category: .back)
        let today = date(0)

        let (vm, _, _, _) = setupMocks(
            exercises: [ex1, ex2, ex3],
            entries: [
                ex1.id: [makeEntry(exerciseId: ex1.id, date: today, sets: [(20, 10)])],
                ex2.id: [makeEntry(exerciseId: ex2.id, date: today, sets: [(40, 10)])],
                ex3.id: [makeEntry(exerciseId: ex3.id, date: today, sets: [(30, 10)])],
            ]
        )
        let days = vm.getTrainingDays()

        #expect(days.count == 1)
    }

    @Test func returnsSortedDates() {
        let ex1 = makeExercise(name: "Ex1", category: .arms)
        let ex2 = makeExercise(name: "Ex2", category: .chest)
        let ex3 = makeExercise(name: "Ex3", category: .back)
        let day1 = date(-3)
        let day2 = date(-1)

        let (vm, _, _, _) = setupMocks(
            exercises: [ex1, ex2, ex3],
            entries: [
                ex1.id: [
                    makeEntry(exerciseId: ex1.id, date: day1, sets: [(20, 10)]),
                    makeEntry(exerciseId: ex1.id, date: day2, sets: [(20, 10)]),
                ],
                ex2.id: [
                    makeEntry(exerciseId: ex2.id, date: day1, sets: [(40, 10)]),
                    makeEntry(exerciseId: ex2.id, date: day2, sets: [(40, 10)]),
                ],
                ex3.id: [
                    makeEntry(exerciseId: ex3.id, date: day1, sets: [(30, 10)]),
                    makeEntry(exerciseId: ex3.id, date: day2, sets: [(30, 10)]),
                ],
            ]
        )
        let days = vm.getTrainingDays()

        #expect(days.count == 2)
        #expect(days[0] < days[1])
    }
}

// MARK: - allDatesWithData

@Suite("allDatesWithData", .tags(.fast))
@MainActor
struct AllDatesWithDataTests {

    @Test func returnsEmptyWhenNoEntries() {
        let (vm, _, _, _) = setupMocks()

        #expect(vm.allDatesWithData().isEmpty)
    }

    @Test func returnsUniqueDaysAcrossExercises() {
        let ex1 = makeExercise(name: "Curl", category: .arms)
        let ex2 = makeExercise(name: "Bench", category: .chest)
        let day1 = date(-1)
        let day2 = date(0)

        let (vm, _, _, _) = setupMocks(
            exercises: [ex1, ex2],
            entries: [
                ex1.id: [
                    makeEntry(exerciseId: ex1.id, date: day1, sets: [(20, 10)]),
                    makeEntry(exerciseId: ex1.id, date: day2, sets: [(20, 10)]),
                ],
                ex2.id: [
                    makeEntry(exerciseId: ex2.id, date: day1, sets: [(60, 10)]),
                ],
            ]
        )
        let dates = vm.allDatesWithData()

        #expect(dates.count == 2)
    }
}

// MARK: - getTrainingRhythm

@Suite("getTrainingRhythm", .tags(.fast))
@MainActor
struct GetTrainingRhythmTests {

    @Test func returnsNotEnoughDataForFewDays() {
        let (vm, _, _, _) = setupMocks()

        #expect(vm.getTrainingRhythm() == "Not enough data")
    }

    @Test func returnsWeeklyForDailyTraining() {
        let ex1 = makeExercise(name: "Ex1", category: .arms)
        let ex2 = makeExercise(name: "Ex2", category: .chest)
        let ex3 = makeExercise(name: "Ex3", category: .back)

        var entries1: [AnalyticsEntry] = []
        var entries2: [AnalyticsEntry] = []
        var entries3: [AnalyticsEntry] = []

        for offset in stride(from: -6, through: 0, by: 2) {
            let d = date(offset)
            entries1.append(makeEntry(exerciseId: ex1.id, date: d, sets: [(20, 10)]))
            entries2.append(makeEntry(exerciseId: ex2.id, date: d, sets: [(40, 10)]))
            entries3.append(makeEntry(exerciseId: ex3.id, date: d, sets: [(30, 10)]))
        }

        let (vm, _, _, _) = setupMocks(
            exercises: [ex1, ex2, ex3],
            entries: [
                ex1.id: entries1,
                ex2.id: entries2,
                ex3.id: entries3,
            ]
        )
        #expect(vm.getTrainingRhythm() == "Weekly")
    }
}

// MARK: - totalWorkoutDaysInCurrentMonth

@Suite("totalWorkoutDaysInCurrentMonth", .tags(.fast))
@MainActor
struct TotalWorkoutDaysInCurrentMonthTests {

    @Test func returnsZeroWhenNoData() {
        let (vm, _, _, _) = setupMocks()

        #expect(vm.totalWorkoutDaysInCurrentMonth() == 0)
    }

    @Test func countsDistinctDaysInCurrentMonth() {
        let ex = makeExercise(category: .arms)
        let today = date(0)

        let (vm, _, _, _) = setupMocks(
            exercises: [ex],
            entries: [ex.id: [
                makeEntry(exerciseId: ex.id, date: today, sets: [(20, 10)]),
            ]]
        )
        #expect(vm.totalWorkoutDaysInCurrentMonth() >= 1)
    }
}

// MARK: - getCategoryWithMostImprovements

@Suite("getCategoryWithMostImprovements", .tags(.fast))
@MainActor
struct GetCategoryWithMostImprovementsTests {

    @Test func returnsCategoryWithHighestWeightIncrements() {
        let armEx = makeExercise(name: "Curl", category: .arms)
        let chestEx = makeExercise(name: "Bench", category: .chest)

        let (vm, _, _, _) = setupMocks(
            exercises: [armEx, chestEx],
            entries: [
                armEx.id: [
                    makeEntry(exerciseId: armEx.id, date: date(-2), sets: [(20, 10)]),
                    makeEntry(exerciseId: armEx.id, date: date(-1), sets: [(22, 10)]),
                    makeEntry(exerciseId: armEx.id, date: date(0), sets: [(25, 10)]),
                ],
                chestEx.id: [
                    makeEntry(exerciseId: chestEx.id, date: date(-1), sets: [(60, 10)]),
                    makeEntry(exerciseId: chestEx.id, date: date(0), sets: [(65, 10)]),
                ],
            ]
        )
        let result = vm.getCategoryWithMostImprovements()

        #expect(result.category == .arms)
        #expect(result.improvements == 2)
    }
}

// MARK: - getLastTrainingDayCompletionRate

@Suite("getLastTrainingDayCompletionRate", .tags(.fast))
@MainActor
struct GetLastTrainingDayCompletionRateTests {

    @Test func returnsZeroWhenNoTrainingDays() {
        let (vm, _, _, _) = setupMocks()
        let result = vm.getLastTrainingDayCompletionRate()

        #expect(result.percentage == 0)
    }
}
