import Testing
import Foundation
import FitnessCore
@testable import FitnessTraining
@testable import FitnessTrainingTestSupport
import FitnessTestSupport

/// Actions that must reset `timerSeconds` to zero when executed
/// after a training session has been running for some time.
enum TimerResetAction: CaseIterable, CustomStringConvertible, Sendable {
    case completeLastSet
    case cancelActiveSet
    case startQuickDone
    case completeAllQuickDone
    case updateRepsCompletingAllSets

    var description: String {
        switch self {
        case .completeLastSet: "completeLastSet"
        case .cancelActiveSet: "cancelActiveSet"
        case .startQuickDone: "startQuickDone"
        case .completeAllQuickDone: "completeAllQuickDone"
        case .updateRepsCompletingAllSets: "updateRepsCompletingAllSets"
        }
    }
}

@Suite("ActiveSetViewModel — Timer Resets", .tags(.fast))
@MainActor
struct ActiveSetViewModelTimerResetTests {

    private func makeSUT() -> (ActiveSetViewModel, FakeClock, TimerService) {
        let clock = FakeClock()
        let timerService = TimerService(clock: clock, tickInterval: .milliseconds(5))
        let vm = ActiveSetViewModel(timerService: timerService)
        return (vm, clock, timerService)
    }

    private func makeExercise(sets: Int = 2) -> Exercise {
        FitnessTestSupport.makeExercise(name: "Curl", weight: 20, reps: 10, sets: sets, category: .arms)
    }

    // MARK: - Parametrized Timer Reset

    @Test("Timer resets to zero", arguments: TimerResetAction.allCases)
    func timerResetsToZero(action: TimerResetAction) {
        let (sut, clock, timerService) = makeSUT()
        let exercise = makeExercise(sets: 2)

        sut.startSet(for: exercise, category: .arms)
        clock.advance(by: 5)
        #expect(timerService.isRunning, "Precondition: timer must be running before the action")
        #expect(timerService.elapsedSeconds() == 5)

        switch action {
        case .completeLastSet:
            sut.completeCurrentSet()
            sut.startNextSet()
            clock.advance(by: 3)
            sut.completeCurrentSet()

        case .cancelActiveSet:
            sut.cancelActiveSet()

        case .startQuickDone:
            sut.startQuickDone(for: exercise, category: .arms)

        case .completeAllQuickDone:
            sut.completeAllQuickDone()

        case .updateRepsCompletingAllSets:
            sut.completeCurrentSet()
            sut.startNextSet()
            sut.updateCurrentReps(8, 15)
        }

        #expect(sut.timerSeconds == 0, "Timer must be zero after \(action)")
        #expect(!timerService.isRunning, "Timer must be stopped after \(action)")
    }

    // MARK: - @Observable Forwarding

    @Test("timerSeconds forwards from TimerService")
    func timerSecondsForwardsFromTimerService() {
        let clock = FakeClock()
        let timerService = TimerService(clock: clock, tickInterval: .seconds(1))
        let sut = ActiveSetViewModel(timerService: timerService)

        timerService.timerSeconds = 42

        #expect(sut.timerSeconds == 42)
    }

    // MARK: - Timer still running after non-terminal actions

    @Test("Timer stops but preserves value after non-last completeCurrentSet, then restarts on startNextSet")
    func timerStopsAndRestartsAcrossSets() {
        let (sut, clock, timerService) = makeSUT()
        let exercise = makeExercise(sets: 3)

        sut.startSet(for: exercise, category: .arms)
        clock.advance(by: 5)
        #expect(timerService.isRunning)
        #expect(timerService.elapsedSeconds() == 5)

        sut.completeCurrentSet()

        #expect(!timerService.isRunning,
                "Non-last completeCurrentSet stops the timer")

        sut.startNextSet()

        #expect(timerService.isRunning, "Timer must restart after startNextSet")
        #expect(timerService.elapsedSeconds() == 0, "Timer must have been reset before restarting")

        clock.advance(by: 3)
        #expect(timerService.elapsedSeconds() == 3, "Timer must accumulate after restart")
    }

    @Test("Timer restarts on startSet")
    func timerRestartsOnStartSet() {
        let (sut, clock, timerService) = makeSUT()
        let exercise = makeExercise(sets: 2)

        sut.startSet(for: exercise, category: .arms)
        clock.advance(by: 5)
        #expect(timerService.elapsedSeconds() == 5)

        sut.startSet(for: exercise, category: .arms)
        #expect(timerService.elapsedSeconds() == 0, "Timer must reset on new startSet")
        #expect(timerService.isRunning, "Timer must be running after startSet")

        clock.advance(by: 1)
        #expect(timerService.elapsedSeconds() == 1)
    }
}
