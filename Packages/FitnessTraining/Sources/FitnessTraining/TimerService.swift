import Foundation
import Observation

/// Abstracts wall-clock time so `TimerService` can report elapsed seconds
/// deterministically in tests without real waits.
///
/// Nonisolated `Sendable` so the production default (`SystemTimerClock()`) can be
/// constructed from any context.
public protocol TimerClock: Sendable {
    func now() -> Date
}

public struct SystemTimerClock: TimerClock {
    public init() {}
    public func now() -> Date { Date() }
}

@Observable
@MainActor
public final class TimerService {
    public var timerSeconds: Int = 0
    public private(set) var isRunning: Bool = false
    private var timerTask: Task<Void, Never>?
    private var startTime: Date?
    private let clock: any TimerClock
    private let tickInterval: Duration

    public init(
        clock: any TimerClock = SystemTimerClock(),
        tickInterval: Duration = .seconds(1)
    ) {
        self.clock = clock
        self.tickInterval = tickInterval
    }

    /// Starts a live, self-updating tick every `tickInterval`. Idempotent.
    public func startTimer() {
        guard !isRunning else { return }
        let start = clock.now()
        startTime = start
        isRunning = true

        timerTask?.cancel()
        let interval = tickInterval
        timerTask = Task { [weak self, clock] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                self.timerSeconds = Int(clock.now().timeIntervalSince(start))
            }
        }
    }

    public func resetAndStartTimer() {
        stopTimer()
        timerSeconds = 0
        startTimer()
    }

    public func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
        startTime = nil
    }

    /// Elapsed seconds since the last `startTimer()` (or `resetAndStartTimer()`),
    /// computed synchronously from the clock. Returns 0 when the timer is not
    /// running. Useful for tests that need deterministic elapsed-time readings
    /// without having to drive the async tick loop.
    public func elapsedSeconds() -> Int {
        guard let start = startTime else { return 0 }
        return Int(clock.now().timeIntervalSince(start))
    }
}
