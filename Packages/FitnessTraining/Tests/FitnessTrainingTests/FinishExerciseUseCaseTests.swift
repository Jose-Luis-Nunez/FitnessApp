import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessAnalytics
import FitnessTestSupport

@Suite("FinishExerciseUseCase", .tags(.fast))
@MainActor
struct FinishExerciseUseCaseTests {

    private let sut = FinishExerciseUseCase()

    @Test func returnsCompletedExerciseWhenAllSetsDone() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise(sets: 2)
        vm.startSet(for: exercise, category: .arms)
        vm.completeCurrentSet()
        vm.startNextSet()
        vm.completeCurrentSet()

        var updatedExercise: Exercise?
        let analyticsVM = AnalyticsViewModel(storageService: StubAnalyticsStorage())

        let result = sut.execute(
            activeSetViewModel: vm,
            analyticsViewModel: analyticsVM,
            findCategory: { _ in .arms },
            onExerciseUpdate: { ex, _ in updatedExercise = ex }
        )

        #expect(result != nil)
        #expect(result?.isCompleted == true)
        #expect(updatedExercise?.isCompleted == true)
        #expect(vm.currentExercise == nil)
        #expect(vm.setProgress.isEmpty)
    }

    @Test func persistsEditedSeatFromInFlightSnapshot() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise(sets: 1, seatSetting: "3")
        vm.startSet(for: exercise, category: .arms)
        // Mirror a mid-session seat edit (TrainingCoordinator.updateActiveSeat).
        vm.currentExercise?.seatSetting = "9"
        vm.completeCurrentSet()

        var updatedExercise: Exercise?
        let analyticsVM = AnalyticsViewModel(storageService: StubAnalyticsStorage())

        _ = sut.execute(
            activeSetViewModel: vm,
            analyticsViewModel: analyticsVM,
            findCategory: { _ in .arms },
            onExerciseUpdate: { ex, _ in updatedExercise = ex }
        )

        #expect(updatedExercise?.seatSetting == "9")
    }

    @Test func returnsNilWhenNotAllSetsDone() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise(sets: 3)
        vm.startSet(for: exercise, category: .arms)
        vm.completeCurrentSet()

        let analyticsVM = AnalyticsViewModel(storageService: StubAnalyticsStorage())

        let result = sut.execute(
            activeSetViewModel: vm,
            analyticsViewModel: analyticsVM,
            findCategory: { _ in .arms },
            onExerciseUpdate: { _, _ in }
        )

        #expect(result == nil)
    }

    @Test func returnsNilWhenNoExercise() {
        let vm = ActiveSetViewModel()
        let analyticsVM = AnalyticsViewModel(storageService: StubAnalyticsStorage())

        let result = sut.execute(
            activeSetViewModel: vm,
            analyticsViewModel: analyticsVM,
            findCategory: { _ in nil },
            onExerciseUpdate: { _, _ in }
        )

        #expect(result == nil)
    }

    @Test func progressesIdleWeightWhenEverySetReachesTwelveReps() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise(weight: 20, reps: 10, sets: 3)
        vm.startSet(for: exercise, category: .arms)

        vm.updateCurrentReps(12, 21)
        vm.startNextSet()
        vm.updateCurrentReps(15, 21)
        vm.startNextSet()
        vm.updateCurrentReps(12, 21)

        var updatedExercise: Exercise?
        let analyticsStorage = MockAnalyticsStorage()
        let analyticsVM = AnalyticsViewModel(
            storageService: analyticsStorage,
            saveAnalyticsUseCase: SaveAnalyticsUseCase(analyticsStorage: analyticsStorage)
        )

        _ = sut.execute(
            activeSetViewModel: vm,
            analyticsViewModel: analyticsVM,
            findCategory: { _ in .arms },
            onExerciseUpdate: { exercise, _ in updatedExercise = exercise }
        )

        #expect(updatedExercise?.weight == 21)
        #expect(updatedExercise?.sets == 3)
        #expect(updatedExercise?.reps == 12)
        #expect(updatedExercise?.isCompleted == true)
        #expect(analyticsStorage.load(for: exercise.id).first?.setProgress.map(\.currentReps) == [12, 15, 12])
        #expect(analyticsStorage.load(for: exercise.id).first?.setProgress.map(\.weight) == [21, 21, 21])
    }

    @Test func keepsIdleValuesWhenOneHigherWeightSetFallsBelowTwelveReps() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise(weight: 20, reps: 10, sets: 3)
        vm.startSet(for: exercise, category: .arms)

        vm.updateCurrentReps(12, 21)
        vm.startNextSet()
        vm.updateCurrentReps(8, 21)
        vm.startNextSet()
        vm.updateCurrentReps(12, 21)

        var updatedExercise: Exercise?
        let analyticsVM = AnalyticsViewModel(storageService: StubAnalyticsStorage())

        _ = sut.execute(
            activeSetViewModel: vm,
            analyticsViewModel: analyticsVM,
            findCategory: { _ in .arms },
            onExerciseUpdate: { exercise, _ in updatedExercise = exercise }
        )

        #expect(updatedExercise?.weight == 20)
        #expect(updatedExercise?.sets == 3)
        #expect(updatedExercise?.reps == 10)
        #expect(updatedExercise?.isCompleted == true)
    }
}
