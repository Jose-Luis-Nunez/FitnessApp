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

    exerciseStorage.seedExercises(exercises, workoutId: workout.id)

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
        workoutStorage: workoutStorage
    )

    return (vm, workoutStorage, exerciseStorage, analyticsStorage)
}

// MARK: - getCategoryProgressData

@Suite("getCategoryProgressData", .tags(.fast))
@MainActor
struct GetCategoryProgressDataTests {

    @Test func emptySnapshotReturnsConsistentAnalyticsDefaults() {
        let (vm, _, _, _) = setupMocks()
        let result = vm.getCategoryProgressData()

        #expect(result.count == 5)
        #expect(result.allSatisfy { $0.exercises.isEmpty })
        #expect(vm.getMostTrainedCategory().count == 0)
        #expect(vm.getLeastTrainedCategory().count == 0)
        #expect(vm.getTrainingDays().isEmpty)
        #expect(vm.allDatesWithData().isEmpty)
        #expect(vm.getTrainingRhythm() == .notEnoughData)
        #expect(vm.totalWorkoutDaysInCurrentMonth() == 0)
        #expect(vm.totalWorkoutDaysInYear() == 0)
        let completion = vm.getLastTrainingDayCompletionRate()
        #expect(completion.completed == 0)
        #expect(completion.total == 0)
        #expect(completion.percentage == 0)
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

    @Test func returnsMostAndLeastCategoriesFromOneRanking() {
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
        let most = vm.getMostTrainedCategory()
        let least = vm.getLeastTrainedCategory()

        #expect(most.category == .arms)
        #expect(most.count == 2)
        #expect(least.category == .chest)
        #expect(least.count == 1)
    }
}

// MARK: - getTrainingDays

@Suite("getTrainingDays", .tags(.fast))
@MainActor
struct GetTrainingDaysTests {

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

        #expect(days == [day1, day2])
    }
}

// MARK: - allDatesWithData

@Suite("allDatesWithData", .tags(.fast))
@MainActor
struct AllDatesWithDataTests {

    @Test func dateAggregatesDeduplicateAndRespectMonthAndYearBoundaries() throws {
        let ex1 = makeExercise(name: "Curl", category: .arms)
        let ex2 = makeExercise(name: "Bench", category: .chest)
        let calendar = Calendar.current
        let now = Date()
        let interval = try #require(calendar.dateInterval(of: .month, for: now))
        let day1 = interval.start
        let day2 = try #require(calendar.date(byAdding: .day, value: 1, to: day1))
        let previousYear = try #require(calendar.date(byAdding: .year, value: -1, to: day1))

        let (vm, _, _, _) = setupMocks(
            exercises: [ex1, ex2],
            entries: [
                ex1.id: [
                    makeEntry(exerciseId: ex1.id, date: day1, sets: [(20, 10)]),
                    makeEntry(exerciseId: ex1.id, date: day2, sets: [(20, 10)]),
                ],
                ex2.id: [
                    makeEntry(exerciseId: ex2.id, date: day1, sets: [(60, 10)]),
                    makeEntry(exerciseId: ex2.id, date: previousYear, sets: [(60, 10)]),
                ],
            ]
        )
        let dates = vm.allDatesWithData()

        #expect(dates == Set([day1, day2, previousYear]))
        #expect(vm.totalWorkoutDaysInCurrentMonth() == 2)
        #expect(vm.totalWorkoutDaysInYear() == 2)
    }
}

// MARK: - getTrainingRhythm

@Suite("getTrainingRhythm", .tags(.fast))
@MainActor
struct GetTrainingRhythmTests {

    @Test func mapsAverageGapsToEveryRhythmCategory() {
        let cases: [(offsets: [Int], expected: TrainingRhythm)] = [
            ([0], .notEnoughData),
            ([-7, 0], .weekly),
            ([-14, 0], .biweekly),
            ([-21, 0], .weeks(3)),
        ]

        for testCase in cases {
            let exercises = [
                makeExercise(name: "Ex1", category: .arms),
                makeExercise(name: "Ex2", category: .chest),
                makeExercise(name: "Ex3", category: .back),
            ]
            let entries = Dictionary(uniqueKeysWithValues: exercises.map { exercise in
                (
                    exercise.id,
                    testCase.offsets.map {
                        makeEntry(
                            exerciseId: exercise.id,
                            date: date($0),
                            sets: [(20, 10)]
                        )
                    }
                )
            })
            let (vm, _, _, _) = setupMocks(exercises: exercises, entries: entries)

            #expect(vm.getTrainingRhythm() == testCase.expected, "Offsets: \(testCase.offsets)")
        }
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

    @Test func includesExercisesWithoutHistoryInCompletionDenominator() {
        let completed = [
            makeExercise(name: "Completed 1", category: .arms),
            makeExercise(name: "Completed 2", category: .chest),
            makeExercise(name: "Completed 3", category: .back),
        ]
        let withoutHistory = makeExercise(name: "Not trained", category: .chest)
        let entries = Dictionary(uniqueKeysWithValues: completed.map { exercise in
            (exercise.id, [makeEntry(
                exerciseId: exercise.id,
                date: date(0),
                sets: [(20, 10)]
            )])
        })
        let (vm, _, _, _) = setupMocks(
            exercises: completed + [withoutHistory],
            entries: entries
        )

        let result = vm.getLastTrainingDayCompletionRate()

        #expect(result.completed == 3)
        #expect(result.total == 4)
        #expect(result.percentage == 75)
    }
}

@Suite("snapshot cache invalidation", .tags(.fast))
@MainActor
struct SnapshotCacheInvalidationTests {
    @Test func materializesCompleteDisplayStateFromOneSnapshot() {
        let exercises = [
            makeExercise(name: "Curl", category: .arms),
            makeExercise(name: "Bench", category: .chest),
            makeExercise(name: "Row", category: .back),
        ]
        let firstDay = date(-3)
        let lastDay = date(0)
        let entries = Dictionary(uniqueKeysWithValues: exercises.enumerated().map { index, exercise in
            (
                exercise.id,
                [
                    makeEntry(
                        exerciseId: exercise.id,
                        date: firstDay,
                        sets: [(Double(20 + index * 10), 10)]
                    ),
                    makeEntry(
                        exerciseId: exercise.id,
                        date: lastDay,
                        sets: [(Double(25 + index * 10), 10)]
                    ),
                ]
            )
        })
        let (vm, _, _, analytics) = setupMocks(exercises: exercises, entries: entries)
        let now = Date(timeIntervalSince1970: 1_893_456_000)

        vm.materializeDisplayState(now: now)

        #expect(analytics.batchLoadCallCount == 1)
        #expect(vm.displayState.datesWithData.count == 2)
        #expect(vm.displayState.categoryProgress.flatMap(\.exercises).count == 3)
        #expect(vm.displayState.workoutDetail?.categories.flatMap(\.exercises).count == 3)
        #expect(vm.displayState.rhythmDetail?.trainingDates.count == 2)
        #expect(vm.displayState.tiles.map(\.kind) == [
            .currentMonthTraining,
            .currentYearTraining,
            .lastWorkoutCompletion,
            .trainingRhythm,
            .mostTrainedCategory,
            .leastTrainedCategory,
            .mostImprovedCategory,
        ])
        #expect(vm.displayState.tiles[2].value == .percentage(100))
        #expect(vm.displayState.tiles[3].value == .rhythm(.weekly))
        #expect(vm.displayState.tiles[1].label == .trainingYear(2030))
    }

    @Test func refreshDataObservesNewBackingEntries() {
        let exercise = makeExercise(name: "Curl", category: .arms)
        let initial = makeEntry(exerciseId: exercise.id, date: date(-1), sets: [(20, 10)])
        let (vm, _, _, analytics) = setupMocks(
            exercises: [exercise],
            entries: [exercise.id: [initial]]
        )

        #expect(vm.loadAllAnalytics().map(\.id) == [initial.id])
        let added = makeEntry(exerciseId: exercise.id, date: date(0), sets: [(22, 10)])
        analytics.save([initial, added], for: exercise.id)
        #expect(vm.loadAllAnalytics().map(\.id) == [initial.id])

        vm.refreshData()

        #expect(Set(vm.loadAllAnalytics().map(\.id)) == Set([initial.id, added.id]))
    }

    @Test func failedInitialLoadIsNotCachedAsSuccessfulEmptyHistory() {
        let exercise = makeExercise(name: "Curl", category: .arms)
        let entry = makeEntry(exerciseId: exercise.id, date: date(0), sets: [(20, 10)])
        let (vm, _, _, analytics) = setupMocks(
            exercises: [exercise],
            entries: [exercise.id: [entry]]
        )
        analytics.batchLoadFails = true

        #expect(vm.loadAllAnalytics().isEmpty)
        #expect(analytics.batchLoadCallCount == 1)

        analytics.batchLoadFails = false

        #expect(vm.loadAllAnalytics().map(\.id) == [entry.id])
        #expect(analytics.batchLoadCallCount == 2)
    }

    @Test func failedRefreshKeepsOneCoherentSnapshotForTheSameWorkout() {
        let exercise = makeExercise(name: "Curl", category: .arms)
        let initial = makeEntry(exerciseId: exercise.id, date: date(-1), sets: [(20, 10)])
        let (vm, _, _, analytics) = setupMocks(
            exercises: [exercise],
            entries: [exercise.id: [initial]]
        )
        vm.materializeDisplayState()
        let initialDates = vm.displayState.datesWithData

        analytics.save([
            initial,
            makeEntry(exerciseId: exercise.id, date: date(0), sets: [(22, 10)]),
        ], for: exercise.id)
        analytics.batchLoadFails = true

        vm.materializeDisplayState()

        #expect(vm.displayState.datesWithData == initialDates)

        analytics.batchLoadFails = false
        vm.materializeDisplayState()

        #expect(vm.displayState.datesWithData.count == 2)
    }
}
