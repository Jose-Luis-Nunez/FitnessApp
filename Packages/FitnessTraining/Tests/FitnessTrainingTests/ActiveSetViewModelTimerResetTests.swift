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

    private func makeSUT(
        tickInterval: Duration = .milliseconds(5)
    ) -> (ActiveSetViewModel, FakeClock) {
        let clock = FakeClock()
        let timerService = TimerService(clock: clock, tickInterval: tickInterval)
        let vm = ActiveSetViewModel(timerService: timerService)
        return (vm, clock)
    }

    private func makeExercise(sets: Int = 2) -> Exercise {
        FitnessTestSupport.makeExercise(name: "Curl", weight: 20, reps: 10, sets: sets, category: .arms)
    }

    // MARK: - Parametrized Timer Reset

    @Test("Timer resets to zero", arguments: TimerResetAction.allCases)
    func timerResetsToZero(action: TimerResetAction) async throws {
        let (sut, clock) = makeSUT()
        let exercise = makeExercise(sets: 2)

        sut.startSet(for: exercise, category: .arms)

        clock.advance(by: 5)
        try await waitUntil(timeout: .milliseconds(500)) { sut.timerSeconds >= 1 }
        #expect(sut.timerSeconds > 0, "Precondition: timer must be running before the action")

        switch action {
        case .completeLastSet:
            sut.completeCurrentSet()
            sut.startNextSet()
            clock.advance(by: 3)
            try await waitUntil(timeout: .milliseconds(500)) { sut.timerSeconds >= 1 }
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
            clock.advance(by: 2)
            try await waitUntil(timeout: .milliseconds(500)) { sut.timerSeconds >= 1 }
            sut.updateCurrentReps(8, 15)
        }

        #expect(sut.timerSeconds == 0, "Timer must be zero after \(action)")
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
    func timerStopsAndRestartsAcrossSets() async throws {
        let (sut, clock) = makeSUT()
        let exercise = makeExercise(sets: 3)

        sut.startSet(for: exercise, category: .arms)
        clock.advance(by: 5)
        try await waitUntil(timeout: .milliseconds(500)) { sut.timerSeconds >= 1 }
        let frozenValue = sut.timerSeconds

        sut.completeCurrentSet()

        #expect(sut.timerSeconds == frozenValue,
                "Non-last completeCurrentSet stops the timer but does not zero it")

        sut.startNextSet()

        clock.advance(by: 3)
        try await waitUntil(timeout: .milliseconds(500)) { sut.timerSeconds >= 1 }
        #expect(sut.timerSeconds >= 1, "Timer must restart after startNextSet")
        #expect(sut.timerSeconds < frozenValue, "Timer must have been reset before restarting")
    }

    @Test("Timer restarts on startSet")
    func timerRestartsOnStartSet() async throws {
        let (sut, clock) = makeSUT()
        let exercise = makeExercise(sets: 2)

        sut.startSet(for: exercise, category: .arms)
        clock.advance(by: 5)
        try await waitUntil(timeout: .milliseconds(500)) { sut.timerSeconds >= 1 }
        let firstReading = sut.timerSeconds

        sut.startSet(for: exercise, category: .arms)
        clock.advance(by: 1)
        try await waitUntil(timeout: .milliseconds(500)) { sut.timerSeconds >= 1 }

        #expect(sut.timerSeconds < firstReading, "Timer must reset on new startSet")
    }
}
