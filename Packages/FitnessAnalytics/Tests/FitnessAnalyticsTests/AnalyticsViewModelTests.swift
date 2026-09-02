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

// MARK: - repsIncreases

@Suite("repsIncreases", .tags(.fast))
@MainActor
struct RepsIncreasesTests {

    @Test func returnsEmptyForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        #expect(vm.repsIncreases(from: []).isEmpty)
    }

    /// Bodyweight exercises step up in reps, and the opening rep level is no
    /// more an increase than an opening weight is.
    @Test func theOpeningPhaseIsNotReturned() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-3), sets: [(0, 8)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(0, 8)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 12)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 12)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.repsIncreases(from: storage.load(for: id))

        #expect(phases.count == 1)
        #expect(phases[0].value == .reps(12))
        #expect(phases[0].previousSession.value == .reps(8))
    }

    /// Rep maxima wobble session to session, so a drop must not be announced as
    /// an increase — otherwise nearly every bodyweight exercise would show false
    /// tiles.
    @Test func aRepDropIsNotAnIncrease() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 20)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 18)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.repsIncreases(from: storage.load(for: id)).isEmpty)
    }

    @Test func aSingleRepLevelYieldsNothing() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 8)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 8)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.repsIncreases(from: storage.load(for: id)).isEmpty)
    }

    /// The endpoint carries reps, not weight — this path leaves `weight` at 0,
    /// so a tile that printed it would read "0 kg".
    @Test func previousSessionCarriesRepsNotWeight() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-2), sets: [(0, 8)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 8), (0, 8)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 12)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.repsIncreases(from: storage.load(for: id))

        #expect(phases.count == 1)
        let previous = phases[0].previousSession
        #expect(previous.value == .reps(8))
        #expect(previous.date == date(-1))
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
        let phases = vm.repsIncreases(from: storage.load(for: id), limit: 2)

        #expect(phases.count == 2)
        #expect(phases.map(\.value) == [.reps(12), .reps(14)])
        #expect(phases.map(\.previousSession.value) == [.reps(10), .reps(12)])
    }

    @Test func setLabelCountsOnlySetsAtMaximumWeight() throws {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            // A lighter phase in front, so the day under test is an increase and
            // therefore returned at all. Its own label is what is asserted.
            makeEntry(exerciseId: id, date: date(-1), sets: [(30, 10)]),
            makeEntry(
                exerciseId: id,
                date: date(0),
                sets: [(40, 12), (50, 8), (50, 10)]
            )
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phase = try #require(vm.weightIncreases(from: storage.load(for: id)).first)

        #expect(phase.startSetsReps == "2×8")
    }

    @Test func bilateralPhasePairsAsymmetricWeightsBeforeSelectingMaximum() throws {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-1), sets: [(10, 5)]),
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
        let phase = try #require(vm.weightIncreases(from: storage.load(for: id)).first)

        #expect(phase.value == .weight(22))
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

// MARK: - weightIncreases

@Suite("weightIncreases", .tags(.fast))
@MainActor
struct WeightIncreasesTests {

    @Test func returnsEmptyForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        #expect(vm.weightIncreases(from: []).isEmpty)
    }

    /// Four days at two weights are two raw phases, but only one of them is an
    /// increase: the 40kg phase is where the exercise started.
    @Test func theOpeningPhaseIsNotReturned() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-3), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(60, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(60, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.weightIncreases(from: storage.load(for: id))

        #expect(phases.count == 1)
        #expect(phases[0].value == .weight(60))
        #expect(phases[0].previousSession.value == .weight(40))
    }

    /// An exercise trained only ever at one weight has increased nothing, so it
    /// has nothing to show — this empty result is also what hides the button
    /// that opens the feature.
    @Test func aSingleWeightYieldsNothing() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-2), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(40, 12)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(40, 14)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.weightIncreases(from: storage.load(for: id)).isEmpty)
    }

    /// The previous session must be the **last** day at the old weight — the
    /// workout the increase was actually earned with — and its weight, sets and
    /// date must all come from that same day. The three 20kg days deliberately
    /// differ in set count so a wrong day is visible in `setsReps`.
    @Test func previousSessionComesFromThePrecedingPhaseLastDay() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-3), sets: [(20, 10)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(20, 10), (20, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(20, 10), (20, 10), (20, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(26, 12)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.weightIncreases(from: storage.load(for: id))

        #expect(phases.count == 1)
        let previous = phases[0].previousSession
        #expect(previous.value == .weight(20))
        #expect(previous.setsReps == "3×10")
        #expect(previous.date == date(-1))
    }

    /// A phase boundary is any change of weight, so a deload opens one too. It is
    /// not progress: no tile, and therefore no coaching affordance either.
    @Test func aDeloadIsNotAnIncrease() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-2), sets: [(60, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(60, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(50, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.weightIncreases(from: storage.load(for: id)).isEmpty)
    }

    /// A deload between two increases is skipped, not treated as the predecessor
    /// of what follows it.
    @Test func aDeloadIsSkippedBetweenIncreases() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-3), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(60, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(50, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(70, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.weightIncreases(from: storage.load(for: id))

        #expect(phases.map(\.value) == [.weight(60), .weight(70)])
        #expect(phases.map(\.previousSession.value) == [.weight(40), .weight(50)])
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
        let phases = vm.weightIncreases(from: storage.load(for: id), limit: 2)

        #expect(phases.map(\.value) == [.weight(60), .weight(70)])
    }

    /// The predecessor is read from the full phase list, not from the truncated
    /// window, so the oldest returned phase still knows what came before it.
    @Test func previousSessionSurvivesTruncation() {
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
        let phases = vm.weightIncreases(from: storage.load(for: id))

        #expect(phases.map(\.value) == [.weight(50), .weight(60), .weight(70)])
        #expect(phases.map(\.previousSession.value) == [.weight(40), .weight(50), .weight(60)])
    }

    /// The header says "Reached in N days / with N workouts", so both numbers
    /// describe the way *to* the new weight: the gap from the last workout at the
    /// old weight to the first at the new one, and the workouts spent earning it.
    /// They previously described the time spent *at* the new weight, which the
    /// tile's own two dates contradicted.
    @Test func theSummaryDescribesTheWayToTheNewWeight() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-3), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-2), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(-1), sets: [(60, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(60, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.weightIncreases(from: storage.load(for: id))

        #expect(phases.count == 1)
        // Last 40kg day was date(-2), first 60kg day date(-1).
        #expect(phases[0].daysToReach == 1)
        // Two workouts were done at 40kg before the step up.
        #expect(phases[0].workoutsToReach == 2)
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
