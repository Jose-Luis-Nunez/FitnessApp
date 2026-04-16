import Testing
import Foundation
import FitnessTestSupport
@testable import FitnessTraining

/// Deterministic clock for unit tests — `now()` is controlled explicitly.
/// `@unchecked Sendable` because `TimerClock` is nonisolated and may be read
/// from the timer task while the test advances time on the main actor.
private final class FakeClock: TimerClock, @unchecked Sendable {
    private let lock = NSLock()
    private var _currentTime: Date

    init(start: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self._currentTime = start
    }

    func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return _currentTime
    }

    func advance(by seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        _currentTime = _currentTime.addingTimeInterval(seconds)
    }
}

@Suite("TimerService")
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

    @Test func elapsedSecondsIsZeroWhenNotRunning() {
        let (sut, clock) = makeSUT()
        clock.advance(by: 100)
        #expect(sut.elapsedSeconds() == 0)
    }

    @Test func elapsedSecondsFreezesAfterStop() {
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

    @Test func multipleStopCallsAreIdempotent() {
        let (sut, _) = makeSUT()
        sut.startTimer()

        sut.stopTimer()
        sut.stopTimer()

        #expect(sut.isRunning == false)
    }

    // MARK: - Live tick loop (deterministic)

    /// Verifies that the internal tick loop actually publishes to `timerSeconds`
    /// as the clock advances. Uses a short `tickInterval` + `FakeClock` so the
    /// test is deterministic and fast (no real-time sleeps beyond the tick
    /// itself). This exercises the same production code path as the 1-second
    /// live timer — only the tick cadence differs.
    @Test(.timeLimit(.minutes(1)))
    func tickLoopPublishesElapsedSecondsWhenClockAdvances() async throws {
        let clock = FakeClock()
        let sut = TimerService(clock: clock, tickInterval: .milliseconds(5))
        sut.startTimer()

        clock.advance(by: 1)
        try await waitUntil(timeout: .milliseconds(500)) { sut.timerSeconds >= 1 }
        let afterOne = sut.timerSeconds

        clock.advance(by: 2)
        try await waitUntil(timeout: .milliseconds(500)) { sut.timerSeconds >= 3 }
        let afterThree = sut.timerSeconds

        sut.stopTimer()

        #expect(afterOne == 1)
        #expect(afterThree == 3)
        #expect(sut.isRunning == false)
    }
}
