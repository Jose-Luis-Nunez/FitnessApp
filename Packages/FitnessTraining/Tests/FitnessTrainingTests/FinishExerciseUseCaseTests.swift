import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessAnalytics
import FitnessTestSupport
import Factory

@Suite("FinishExerciseUseCase")
@MainActor
struct FinishExerciseUseCaseTests {

    private let sut = FinishExerciseUseCase()

    @Test func returnsCompletedExerciseWhenAllSetsDone() {
        Container.shared.reset()
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

    @Test func returnsNilWhenNotAllSetsDone() {
        Container.shared.reset()
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
        Container.shared.reset()
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

    @Test func resetsQuickDoneMode() {
        Container.shared.reset()
        let vm = ActiveSetViewModel()
        let exercise = makeExercise(sets: 1)
        vm.startSet(for: exercise, category: .arms)
        vm.quickDoneModeActive = true
        vm.completeCurrentSet()

        let analyticsVM = AnalyticsViewModel(storageService: StubAnalyticsStorage())

        _ = sut.execute(
            activeSetViewModel: vm,
            analyticsViewModel: analyticsVM,
            findCategory: { _ in .arms },
            onExerciseUpdate: { _, _ in }
        )

        #expect(vm.quickDoneModeActive == false)
    }
}
