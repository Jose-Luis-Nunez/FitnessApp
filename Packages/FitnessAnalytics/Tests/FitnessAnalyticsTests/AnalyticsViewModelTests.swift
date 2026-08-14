import Testing
import Foundation
import os
@testable import FitnessAnalytics
import FitnessCore
import FitnessTestSupport

// MARK: - Helpers

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

private func date(_ offset: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date()))!
}

// MARK: - getDailyRepsProgression

@Suite("getDailyRepsProgression", .tags(.fast))
@MainActor
struct GetDailyRepsProgressionTests {

    @Test func returnsEmptyForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        let result = vm.getDailyRepsProgression(from: [])
        #expect(result.isEmpty)
    }

    @Test func takesMaxRepsAcrossSetsPerEntry() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 8), (0, 12), (0, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let result = vm.getDailyRepsProgression(from: storage.load(for: id))

        #expect(result.count == 1)
        #expect(result[0].value == 12)
    }

    @Test func takesMaxRepsAcrossMultipleEntriesSameDay() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        let today = date(0)
        storage.save([
            makeEntry(exerciseId: id, date: today, sets: [(0, 8)]),
            makeEntry(exerciseId: id, date: today, sets: [(0, 15)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let result = vm.getDailyRepsProgression(from: storage.load(for: id))

        #expect(result.count == 1)
        #expect(result[0].value == 15)
    }

    @Test func returnsMultipleDaysSorted() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-2), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 12)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 14)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let result = vm.getDailyRepsProgression(from: storage.load(for: id))

        #expect(result.count == 3)
        #expect(result[0].value == 10)
        #expect(result[1].value == 12)
        #expect(result[2].value == 14)
    }
}

// MARK: - totalRepsIncreases

@Suite("totalRepsIncreases", .tags(.fast))
@MainActor
struct TotalRepsIncreasesTests {

    @Test func returnsZeroForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        #expect(vm.totalRepsIncreases(from: []) == 0)
    }

    @Test func returnsZeroForPlateau() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-2), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.totalRepsIncreases(from: storage.load(for: id)) == 0)
    }

    @Test func countsMultipleIncreases() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-3), sets: [(0, 8)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 12)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.totalRepsIncreases(from: storage.load(for: id)) == 2)
    }

    @Test func doesNotCountDecreases() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-2), sets: [(0, 12)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 14)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.totalRepsIncreases(from: storage.load(for: id)) == 1)
    }
}

// MARK: - trainingSessionsUntilRepsIncrease

@Suite("trainingSessionsUntilRepsIncrease", .tags(.fast))
@MainActor
struct TrainingSessionsUntilRepsIncreaseTests {

    @Test func returnsZeroForLessThanThreeDays() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 12)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.trainingSessionsUntilRepsIncrease(from: storage.load(for: id)) == 0)
    }

    @Test func returnsZeroForNoIncreases() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-3), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.trainingSessionsUntilRepsIncrease(from: storage.load(for: id)) == 0)
    }

    @Test func detectsRegularPattern() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        // Pattern: increase every 3 sessions
        storage.save([
            makeEntry(exerciseId: id, date: date(-8), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(-7), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(-6), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(-5), sets: [(0, 12)]),
            makeEntry(exerciseId: id, date: date(-4), sets: [(0, 12)]),
            makeEntry(exerciseId: id, date: date(-3), sets: [(0, 12)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(0, 14)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 14)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 14)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.trainingSessionsUntilRepsIncrease(from: storage.load(for: id)) == 3)
    }
}

// MARK: - repsPhases

@Suite("repsPhases", .tags(.fast))
@MainActor
struct RepsPhasesTests {

    @Test func returnsEmptyForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        #expect(vm.repsPhases(from: []).isEmpty)
    }

    @Test func returnsMultiplePhases() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-3), sets: [(0, 8)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(0, 8)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 12)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 12)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.repsPhases(from: storage.load(for: id))

        #expect(phases.count == 2)
        #expect(phases[0].maxReps == 8)
        #expect(phases[1].maxReps == 12)
        #expect(phases.map(\.sessionCount) == [2, 2])
    }

    @Test func respectsLimitParameter() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-4), sets: [(0, 6)]),
            makeEntry(exerciseId: id, date: date(-3), sets: [(0, 8)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 12)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 14)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.repsPhases(from: storage.load(for: id), limit: 2)

        #expect(phases.count == 2)
        #expect(phases[0].maxReps == 12)
        #expect(phases[1].maxReps == 14)
    }

    @Test func detectsImprovement() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-2), sets: [(0, 8), (0, 6)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 8), (0, 8)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.repsPhases(from: storage.load(for: id))

        #expect(phases.count == 2)
        let firstPhase = phases[0]
        #expect(firstPhase.hasImproved == true)
    }

    @Test func setLabelCountsOnlySetsAtMaximumWeight() throws {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(
                exerciseId: id,
                date: date(0),
                sets: [(40, 12), (50, 8), (50, 10)]
            )
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phase = try #require(vm.weightPhases(from: storage.load(for: id)).first)

        #expect(phase.startSetsReps == "2×8")
    }

    @Test func standardPhaseImprovementStillUsesRepsAtMaximumWeight() throws {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-1), sets: [(50, 5), (40, 1)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(50, 5), (40, 100)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phase = try #require(vm.weightPhases(from: storage.load(for: id)).first)

        #expect(phase.hasImproved == false)
    }

    @Test func bilateralPhaseImprovementSumsActualRepsFromBothSides() throws {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeBilateralEntry(exerciseId: id, date: date(-1), secondaryReps: 8),
            makeBilateralEntry(exerciseId: id, date: date(0), secondaryReps: 12)
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phase = try #require(vm.weightPhases(from: storage.load(for: id)).first)

        #expect(phase.hasImproved == true)
    }

    @Test func bilateralPhasePairsAsymmetricWeightsBeforeSelectingMaximum() throws {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            AnalyticsEntry(
                exerciseId: id,
                date: date(0),
                setProgress: [
                    bilateralSet(side: .left, logicalSetIndex: 0, reps: 12, weight: 20),
                    bilateralSet(side: .right, logicalSetIndex: 0, reps: 10, weight: 22),
                    bilateralSet(side: .left, logicalSetIndex: 1, reps: 11, weight: 22),
                    bilateralSet(side: .right, logicalSetIndex: 1, reps: 12, weight: 21)
                ]
            )
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phase = try #require(vm.weightPhases(from: storage.load(for: id)).first)

        #expect(phase.weight == 22)
        #expect(phase.startSetsReps == "2×10 / side")
    }

    @Test func saveGoalParsesSupportedInputsAndUsesTargetedUpdate() {
        let cases: [(input: String, initial: Double?, expected: Double?)] = [
            ("42.5", nil, 42.5),
            ("42,5", nil, 42.5),
            ("   ", 12, nil),
            ("invalid", 12, 12),
        ]

        for testCase in cases {
            let exerciseStorage = MockExerciseStorage()
            var exercise = FitnessTestSupport.makeExercise(
                name: "Curl",
                category: .arms,
                goal: testCase.initial
            )
            exerciseStorage.exercisesByCategory[.arms] = [exercise]
            let vm = AnalyticsViewModel(exerciseStorage: exerciseStorage)

            vm.saveGoal(for: &exercise, goalText: testCase.input)

            #expect(exercise.goal == testCase.expected, "Input: \(testCase.input)")
            #expect(exerciseStorage.updatedExercises.map(\.id) == [exercise.id])
            #expect(exerciseStorage.saveForWorkoutCallCount == 0)
            #expect(
                exerciseStorage.exercisesByCategory[.arms]?.first?.goal == testCase.expected,
                "Input: \(testCase.input)"
            )
        }
    }

    private func bilateralSet(
        side: ExerciseSide,
        logicalSetIndex: Int,
        reps: Int,
        weight: Double
    ) -> SetProgress {
        SetProgress(
            status: .completedDone,
            currentReps: reps,
            weight: weight,
            side: side,
            logicalSetIndex: logicalSetIndex
        )
    }

    private func makeBilateralEntry(
        exerciseId: UUID,
        date: Date,
        secondaryReps: Int
    ) -> AnalyticsEntry {
        AnalyticsEntry(
            exerciseId: exerciseId,
            date: date,
            setProgress: [
                SetProgress(
                    status: .completedDone,
                    currentReps: 5,
                    weight: 50,
                    side: .left,
                    logicalSetIndex: 0
                ),
                SetProgress(
                    status: .completedDone,
                    currentReps: 5,
                    weight: 50,
                    side: .right,
                    logicalSetIndex: 0
                ),
                SetProgress(
                    status: .completedDone,
                    currentReps: secondaryReps,
                    weight: 40,
                    side: .left,
                    logicalSetIndex: 1
                ),
                SetProgress(
                    status: .completedDone,
                    currentReps: secondaryReps,
                    weight: 40,
                    side: .right,
                    logicalSetIndex: 1
                )
            ]
        )
    }
}

// MARK: - getDailyWeightProgression

@Suite("getDailyWeightProgression", .tags(.fast))
@MainActor
struct GetDailyWeightProgressionTests {

    @Test func returnsEmptyForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        let result = vm.getDailyWeightProgression(from: [])
        #expect(result.isEmpty)
    }

    @Test func takesMaxWeightAcrossSetsPerDay() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(0), sets: [(40, 10), (60, 8), (50, 12)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let result = vm.getDailyWeightProgression(from: storage.load(for: id))

        #expect(result.count == 1)
        #expect(result[0].value == 60)
    }

    @Test func takesMaxWeightAcrossMultipleEntriesSameDay() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        let today = date(0)
        storage.save([
            makeEntry(exerciseId: id, date: today, sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: today, sets: [(70, 8)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let result = vm.getDailyWeightProgression(from: storage.load(for: id))

        #expect(result.count == 1)
        #expect(result[0].value == 70)
    }

    @Test func returnsMultipleDaysSorted() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-2), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(60, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let result = vm.getDailyWeightProgression(from: storage.load(for: id))

        #expect(result.count == 3)
        #expect(result[0].value == 40)
        #expect(result[1].value == 50)
        #expect(result[2].value == 60)
    }

    @Test func excludesDaysWithZeroWeight() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(50, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let result = vm.getDailyWeightProgression(from: storage.load(for: id))

        #expect(result.count == 1)
        #expect(result[0].value == 50)
    }
}

// MARK: - totalWeightIncreases

@Suite("totalWeightIncreases", .tags(.fast))
@MainActor
struct TotalWeightIncreasesTests {

    @Test func returnsZeroForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        #expect(vm.totalWeightIncreases(from: []) == 0)
    }

    @Test func returnsZeroForPlateau() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-2), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(50, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.totalWeightIncreases(from: storage.load(for: id)) == 0)
    }

    @Test func countsMultipleIncreases() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-3), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(60, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.totalWeightIncreases(from: storage.load(for: id)) == 2)
    }

    @Test func doesNotCountDecreases() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-2), sets: [(60, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(70, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.totalWeightIncreases(from: storage.load(for: id)) == 1)
    }
}

// MARK: - trainingSessionsUntilWeightIncrease

@Suite("trainingSessionsUntilWeightIncrease", .tags(.fast))
@MainActor
struct TrainingSessionsUntilWeightIncreaseTests {

    @Test func returnsZeroForLessThanThreeDays() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-1), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(50, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.trainingSessionsUntilWeightIncrease(from: storage.load(for: id)) == 0)
    }

    @Test func returnsZeroForNoIncreases() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-3), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(50, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.trainingSessionsUntilWeightIncrease(from: storage.load(for: id)) == 0)
    }

    @Test func detectsRegularPattern() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-8), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-7), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-6), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-5), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(-4), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(-3), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(60, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(60, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(60, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.trainingSessionsUntilWeightIncrease(from: storage.load(for: id)) == 3)
    }
}

// MARK: - weightPhases

@Suite("weightPhases", .tags(.fast))
@MainActor
struct WeightPhasesTests {

    @Test func returnsEmptyForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        #expect(vm.weightPhases(from: []).isEmpty)
    }

    @Test func returnsMultiplePhases() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-3), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(60, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(60, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.weightPhases(from: storage.load(for: id))

        #expect(phases.count == 2)
        #expect(phases[0].weight == 40)
        #expect(phases[1].weight == 60)
        #expect(phases.map(\.sessionCount) == [2, 2])
    }

    @Test func respectsLimitParameter() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-4), sets: [(30, 10)]),
            makeEntry(exerciseId: id, date: date(-3), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(60, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(70, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.weightPhases(from: storage.load(for: id), limit: 2)

        #expect(phases.count == 2)
        #expect(phases[0].weight == 60)
        #expect(phases[1].weight == 70)
    }

    @Test func detectsImprovement() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-2), sets: [(50, 8), (50, 6)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(50, 8), (50, 8)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(60, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.weightPhases(from: storage.load(for: id))

        #expect(phases.count == 2)
        let firstPhase = phases[0]
        #expect(firstPhase.hasImproved == true)
    }
}

// MARK: - entries reactive updates

@Suite("entries reactive updates", .tags(.fast))
@MainActor
struct EntriesReactiveUpdateTests {

    @Test func entriesUpdatesAfterDeleteSetFromEntry() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        let entry = makeEntry(exerciseId: id, date: date(0), sets: [(60, 10), (65, 8)])
        storage.save([entry], for: id)

        let vm = AnalyticsViewModel(
            storageService: storage,
            deleteAnalyticsSetUseCase: DeleteAnalyticsSetUseCase(analyticsStorage: storage)
        )
        vm.reloadEntries(for: id)

        #expect(vm.cachedEntries(for: id)?.count == 1)
        #expect(vm.cachedEntries(for: id)?[0].setProgress.count == 2)

        vm.deleteSetFromEntry(exerciseId: id, entryId: entry.id, setIndex: 0)

        #expect(vm.cachedEntries(for: id)?.count == 1)
        #expect(vm.cachedEntries(for: id)?[0].setProgress.count == 1)
        #expect(vm.cachedEntries(for: id)?[0].setProgress[0].weight == 65)
    }

    @Test func saveOrReplaceRefreshesCachedEntry() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        let entry = makeEntry(exerciseId: id, date: date(0), sets: [(60, 10)])
        storage.save([entry], for: id)
        let vm = AnalyticsViewModel(
            storageService: storage,
            saveOrReplaceAnalyticsUseCase: SaveOrReplaceAnalyticsUseCase(analyticsStorage: storage)
        )
        vm.reloadEntries(for: id)

        vm.saveOrReplaceAnalyticsEntry(
            exerciseId: id,
            setProgress: [
                SetProgress(status: .completedMore, currentReps: 12, weight: 65),
            ],
            date: entry.date
        )

        #expect(vm.cachedEntries(for: id)?.count == 1)
        #expect(vm.cachedEntries(for: id)?.first?.setProgress.first?.currentReps == 12)
        #expect(vm.cachedEntries(for: id)?.first?.setProgress.first?.weight == 65)
    }

    @Test func deleteLogicalSetRefreshesCachedEntry() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        let entry = AnalyticsEntry(
            exerciseId: id,
            date: date(0),
            setProgress: (0..<2).flatMap { logicalIndex in
                ExerciseSide.allCases.map { side in
                    SetProgress(
                        status: .completedDone,
                        currentReps: 10,
                        weight: 20,
                        side: side,
                        logicalSetIndex: logicalIndex
                    )
                }
            }
        )
        storage.save([entry], for: id)
        let vm = AnalyticsViewModel(
            storageService: storage,
            deleteAnalyticsSetUseCase: DeleteAnalyticsSetUseCase(analyticsStorage: storage)
        )
        vm.reloadEntries(for: id)

        vm.deleteLogicalSetFromEntry(exerciseId: id, entryId: entry.id, logicalSetIndex: 0)

        let remaining = vm.cachedEntries(for: id)?.first?.setProgress
        #expect(remaining?.count == 2)
        #expect(remaining?.allSatisfy { $0.logicalSetIndex == 1 } == true)
    }

    @Test func deleteTriggersObservationOnEntries() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        let entry = makeEntry(exerciseId: id, date: date(0), sets: [(60, 10), (65, 8)])
        storage.save([entry], for: id)

        let vm = AnalyticsViewModel(
            storageService: storage,
            deleteAnalyticsSetUseCase: DeleteAnalyticsSetUseCase(analyticsStorage: storage)
        )
        vm.reloadEntries(for: id)

        let revision = vm.revisionSource(for: id)
        let observationFired = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            _ = revision.value
        } onChange: {
            observationFired.withLock { $0 = true }
        }

        vm.deleteSetFromEntry(exerciseId: id, entryId: entry.id, setIndex: 0)

        #expect(
            observationFired.withLock { $0 },
            "Deleting a set must publish the affected exercise revision"
        )
    }
}
