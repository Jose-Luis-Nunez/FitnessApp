import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore

@Suite("CompleteSetUseCase")
@MainActor
struct CompleteSetUseCaseTests {

    private let sut = CompleteSetUseCase()

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

    @Test func completesSetAndStartsNext() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise(sets: 3)
        vm.startSet(for: exercise, category: .arms)

        let result = sut.execute(activeSetViewModel: vm)

        #expect(result == true)
        #expect(vm.currentSet == 1)
        #expect(vm.isSetInProgress == true)
    }

    @Test func completesLastSetAndFlagsIt() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise(sets: 2)
        vm.startSet(for: exercise, category: .arms)

        sut.execute(activeSetViewModel: vm)
        sut.execute(activeSetViewModel: vm)

        #expect(vm.isLastSetCompleted == true)
        #expect(vm.currentSet == 2)
    }

    @Test func returnsFalseWhenNoExercise() {
        let vm = ActiveSetViewModel()

        let result = sut.execute(activeSetViewModel: vm)

        #expect(result == false)
    }

    @Test func returnsFalseWhenAllSetsCompleted() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise(sets: 1)
        vm.startSet(for: exercise, category: .arms)

        sut.execute(activeSetViewModel: vm)
        let result = sut.execute(activeSetViewModel: vm)

        #expect(result == false)
    }
}
