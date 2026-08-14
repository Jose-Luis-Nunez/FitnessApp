import Testing
import Foundation
@testable import FitnessTraining
@testable import FitnessTrainingTestSupport

@Suite("TimerService", .tags(.fast))
@MainActor
struct TimerServiceTests {

    private func makeSUT() -> (TimerService, FakeClock) {
        let clock = FakeClock()
        return (TimerService(clock: clock), clock)
    }

    // MARK: - Initial State

    @Test func initialStateIsZero() {
        let (sut, _) = makeSUT()
        #expect(sut.timerSeconds == 0)
        #expect(sut.isRunning == false)
        #expect(sut.elapsedSeconds() == 0)
    }

    // MARK: - elapsedSeconds() — deterministic (no async tick-loop involved)

    @Test func elapsedSecondsReflectsClockAdvancementAfterStart() {
        let (sut, clock) = makeSUT()
        sut.startTimer()

        clock.advance(by: 7)

        #expect(sut.elapsedSeconds() == 7)
        #expect(sut.isRunning == true)
    }

    @Test func stopTimerStopsAndClearsElapsedState() {
        let (sut, clock) = makeSUT()
        sut.startTimer()
        clock.advance(by: 3)

        sut.stopTimer()

        clock.advance(by: 10)
        #expect(sut.elapsedSeconds() == 0)
        #expect(sut.isRunning == false)
    }

    @Test func resetAndStartTimerRebasesElapsedSeconds() {
        let (sut, clock) = makeSUT()
        sut.startTimer()
        clock.advance(by: 5)
        #expect(sut.elapsedSeconds() == 5)

        sut.resetAndStartTimer()
        #expect(sut.elapsedSeconds() == 0)

        clock.advance(by: 2)
        #expect(sut.elapsedSeconds() == 2)
    }

    // MARK: - Idempotency

    @Test func startTimerIsIdempotent() {
        let (sut, clock) = makeSUT()
        sut.startTimer()
        clock.advance(by: 2)
        let first = sut.elapsedSeconds()

        sut.startTimer() // must NOT rewind the anchor
        let second = sut.elapsedSeconds()

        #expect(first == 2)
        #expect(second == first)
    }

}
