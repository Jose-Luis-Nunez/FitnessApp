import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore

@Suite("ResetExerciseUseCase")
@MainActor
struct ResetExerciseUseCaseTests {

    private let sut = ResetExerciseUseCase()

    private func makeExercise(sets: Int = 3) -> Exercise {
        Exercise(
            id: UUID(),
            name: "Curl",
            weight: 20,
            reps: 10,
            sets: sets,
            isCompleted: false,
            iconName: "defaultArmsIcon",
            category: .arms
        )
    }

    @Test func callsResetCallbackAndResetsProgress() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise()
        vm.startSet(for: exercise, category: .arms)
        vm.completeCurrentSet()

        var resetCalled = false
        var resetExercise: Exercise?
        var resetCategory: MuscleCategoryGroup?

        let result = sut.execute(
            activeSetViewModel: vm,
            findCategory: { _ in .arms },
            onExerciseReset: { ex, cat in
                resetCalled = true
                resetExercise = ex
                resetCategory = cat
            }
        )

        #expect(result == true)
        #expect(resetCalled == true)
        #expect(resetExercise?.id == exercise.id)
        #expect(resetCategory == .arms)
        #expect(vm.currentExercise == nil)
        #expect(vm.setProgress.isEmpty)
    }

    @Test func returnsFalseWhenNoExercise() {
        let vm = ActiveSetViewModel()

        let result = sut.execute(
            activeSetViewModel: vm,
            findCategory: { _ in .arms },
            onExerciseReset: { _, _ in }
        )

        #expect(result == false)
    }

    @Test func returnsFalseWhenCategoryNotFound() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise()
        vm.startSet(for: exercise, category: .arms)

        let result = sut.execute(
            activeSetViewModel: vm,
            findCategory: { _ in nil },
            onExerciseReset: { _, _ in }
        )

        #expect(result == false)
    }
}
