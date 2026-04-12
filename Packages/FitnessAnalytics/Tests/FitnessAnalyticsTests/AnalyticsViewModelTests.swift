import Testing
import Foundation
@testable import FitnessAnalytics
import FitnessCore
import FitnessTestSupport
import Factory

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

@Suite("getDailyRepsProgression")
@MainActor
struct GetDailyRepsProgressionTests {

    @Test func returnsEmptyForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        let result = vm.getDailyRepsProgression(for: UUID())
        #expect(result.isEmpty)
    }

    @Test func returnsSingleDay() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([makeEntry(exerciseId: id, date: date(0), sets: [(0, 12)])], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let result = vm.getDailyRepsProgression(for: id)

        #expect(result.count == 1)
        #expect(result[0].value == 12)
    }

    @Test func takesMaxRepsAcrossSetsPerEntry() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 8), (0, 12), (0, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let result = vm.getDailyRepsProgression(for: id)

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
        let result = vm.getDailyRepsProgression(for: id)

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
        let result = vm.getDailyRepsProgression(for: id)

        #expect(result.count == 3)
        #expect(result[0].value == 10)
        #expect(result[1].value == 12)
        #expect(result[2].value == 14)
    }
}

// MARK: - totalRepsIncreases

@Suite("totalRepsIncreases")
@MainActor
struct TotalRepsIncreasesTests {

    @Test func returnsZeroForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        #expect(vm.totalRepsIncreases(for: UUID()) == 0)
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
        #expect(vm.totalRepsIncreases(for: id) == 0)
    }

    @Test func countsSingleIncrease() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 12)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.totalRepsIncreases(for: id) == 1)
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
        #expect(vm.totalRepsIncreases(for: id) == 2)
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
        #expect(vm.totalRepsIncreases(for: id) == 1)
    }
}

// MARK: - trainingSessionsUntilRepsIncrease

@Suite("trainingSessionsUntilRepsIncrease")
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
        #expect(vm.trainingSessionsUntilRepsIncrease(for: id) == 0)
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
        #expect(vm.trainingSessionsUntilRepsIncrease(for: id) == 0)
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
        #expect(vm.trainingSessionsUntilRepsIncrease(for: id) == 3)
    }
}

// MARK: - repsPhases

@Suite("repsPhases")
@MainActor
struct RepsPhasesTests {

    @Test func returnsEmptyForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        #expect(vm.repsPhases(for: UUID()).isEmpty)
    }

    @Test func returnsSinglePhase() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-1), sets: [(0, 10), (0, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(0, 10), (0, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.repsPhases(for: id)

        #expect(phases.count == 1)
        #expect(phases[0].maxReps == 10)
        #expect(phases[0].weight == 0)
        #expect(phases[0].sessionCount == 2)
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
        let phases = vm.repsPhases(for: id)

        #expect(phases.count == 2)
        #expect(phases[0].maxReps == 8)
        #expect(phases[1].maxReps == 12)
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
        let phases = vm.repsPhases(for: id, limit: 2)

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
        let phases = vm.repsPhases(for: id)

        #expect(phases.count == 2)
        let firstPhase = phases[0]
        #expect(firstPhase.hasImproved == true)
    }
}

// MARK: - getDailyWeightProgression

@Suite("getDailyWeightProgression")
@MainActor
struct GetDailyWeightProgressionTests {

    @Test func returnsEmptyForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        let result = vm.getDailyWeightProgression(for: UUID())
        #expect(result.isEmpty)
    }

    @Test func returnsSingleDay() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([makeEntry(exerciseId: id, date: date(0), sets: [(60, 10)])], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let result = vm.getDailyWeightProgression(for: id)

        #expect(result.count == 1)
        #expect(result[0].value == 60)
    }

    @Test func takesMaxWeightAcrossSetsPerDay() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(0), sets: [(40, 10), (60, 8), (50, 12)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let result = vm.getDailyWeightProgression(for: id)

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
        let result = vm.getDailyWeightProgression(for: id)

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
        let result = vm.getDailyWeightProgression(for: id)

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
        let result = vm.getDailyWeightProgression(for: id)

        #expect(result.count == 1)
        #expect(result[0].value == 50)
    }
}

// MARK: - totalWeightIncreases

@Suite("totalWeightIncreases")
@MainActor
struct TotalWeightIncreasesTests {

    @Test func returnsZeroForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        #expect(vm.totalWeightIncreases(for: UUID()) == 0)
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
        #expect(vm.totalWeightIncreases(for: id) == 0)
    }

    @Test func countsSingleIncrease() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-1), sets: [(40, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(50, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        #expect(vm.totalWeightIncreases(for: id) == 1)
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
        #expect(vm.totalWeightIncreases(for: id) == 2)
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
        #expect(vm.totalWeightIncreases(for: id) == 1)
    }
}

// MARK: - trainingSessionsUntilWeightIncrease

@Suite("trainingSessionsUntilWeightIncrease")
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
        #expect(vm.trainingSessionsUntilWeightIncrease(for: id) == 0)
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
        #expect(vm.trainingSessionsUntilWeightIncrease(for: id) == 0)
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
        #expect(vm.trainingSessionsUntilWeightIncrease(for: id) == 3)
    }
}

// MARK: - weightPhases

@Suite("weightPhases")
@MainActor
struct WeightPhasesTests {

    @Test func returnsEmptyForNoData() {
        let vm = AnalyticsViewModel(storageService: MockAnalyticsStorage())
        #expect(vm.weightPhases(for: UUID()).isEmpty)
    }

    @Test func returnsSinglePhase() {
        let storage = MockAnalyticsStorage()
        let id = UUID()
        storage.save([
            makeEntry(exerciseId: id, date: date(-1), sets: [(50, 10), (50, 10)]),
            makeEntry(exerciseId: id, date: date(0), sets: [(50, 10), (50, 10)])
        ], for: id)

        let vm = AnalyticsViewModel(storageService: storage)
        let phases = vm.weightPhases(for: id)

        #expect(phases.count == 1)
        #expect(phases[0].weight == 50)
        #expect(phases[0].sessionCount == 2)
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
        let phases = vm.weightPhases(for: id)

        #expect(phases.count == 2)
        #expect(phases[0].weight == 40)
        #expect(phases[1].weight == 60)
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
        let phases = vm.weightPhases(for: id, limit: 2)

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
        let phases = vm.weightPhases(for: id)

        #expect(phases.count == 2)
        let firstPhase = phases[0]
        #expect(firstPhase.hasImproved == true)
    }
}
