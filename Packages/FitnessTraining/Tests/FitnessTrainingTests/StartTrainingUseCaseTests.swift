import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore

@Suite("StartTrainingUseCase")
@MainActor
struct StartTrainingUseCaseTests {

    private let sut = StartTrainingUseCase()

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

    @Test func startsNewSessionWhenNoExistingData() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise()

        let result = sut.execute(
            exercise: exercise, category: .arms,
            activeSetViewModel: vm, finishPreviousTraining: nil
        )

        guard case .started = result else {
            Issue.record("Expected .started, got \(result)")
            return
        }
        #expect(vm.currentExercise?.id == exercise.id)
        #expect(vm.setProgress.count == 3)
        #expect(vm.isSetInProgress == true)
    }

    @Test func resumesExistingSessionForSameExercise() {
        let vm = ActiveSetViewModel()
        let exercise = makeExercise()

        vm.startSet(for: exercise, category: .arms)
        vm.completeCurrentSet()

        let result = sut.execute(
            exercise: exercise, category: .arms,
            activeSetViewModel: vm, finishPreviousTraining: nil
        )

        guard case .resumed = result else {
            Issue.record("Expected .resumed, got \(result)")
            return
        }
        #expect(vm.currentSet == 1)
    }

    @Test func switchesFromPreviousExerciseAndAutoFinishes() {
        let vm = ActiveSetViewModel()
        let exercise1 = makeExercise()
        let exercise2 = makeExercise()

        vm.startSet(for: exercise1, category: .arms)
        vm.completeCurrentSet()

        var finishCalled = false
        let result = sut.execute(
            exercise: exercise2, category: .arms,
            activeSetViewModel: vm,
            finishPreviousTraining: {
                finishCalled = true
                return nil
            }
        )

        guard case .switchedFrom = result else {
            Issue.record("Expected .switchedFrom, got \(result)")
            return
        }
        #expect(finishCalled == true)
        #expect(vm.currentExercise?.id == exercise2.id)
    }

    @Test func switchPassesThroughCompletedExercise() {
        let vm = ActiveSetViewModel()
        let exercise1 = makeExercise(sets: 1)
        let exercise2 = makeExercise()

        vm.startSet(for: exercise1, category: .arms)
        vm.completeCurrentSet()

        var completed = exercise1
        completed.isCompleted = true

        let result = sut.execute(
            exercise: exercise2, category: .arms,
            activeSetViewModel: vm,
            finishPreviousTraining: { completed }
        )

        guard case .switchedFrom(let prev) = result else {
            Issue.record("Expected .switchedFrom, got \(result)")
            return
        }
        #expect(prev?.isCompleted == true)
        #expect(prev?.id == exercise1.id)
    }
}
