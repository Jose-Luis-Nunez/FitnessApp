import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessTestSupport

@Suite("CancelTrainingUseCase")
@MainActor
struct CancelTrainingUseCaseTests {

    private let sut = CancelTrainingUseCase()

    @Test func clearsActiveSetState() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise()
        vm.startSet(for: exercise, category: .arms)

        #expect(vm.currentExercise != nil)
        #expect(vm.isSetInProgress == true)

        sut.execute(activeSetViewModel: vm)

        #expect(vm.currentExercise == nil)
        #expect(vm.isSetInProgress == false)
        #expect(vm.setProgress.isEmpty)
    }

    @Test func worksOnAlreadyClearedState() {
        let vm = ActiveSetViewModel()

        sut.execute(activeSetViewModel: vm)

        #expect(vm.currentExercise == nil)
        #expect(vm.isSetInProgress == false)
    }
}
