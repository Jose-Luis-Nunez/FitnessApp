import Foundation
import FitnessTraining

/// Deterministic clock for unit tests — `now()` is controlled explicitly.
/// `@unchecked Sendable` because `TimerClock` is nonisolated and may be read
/// from the timer task while the test advances time on the main actor.
public final class FakeClock: TimerClock, @unchecked Sendable {
    private let lock = NSLock()
    private var _currentTime: Date

    public init(start: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self._currentTime = start
    }

    public func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return _currentTime
    }

    public func advance(by seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        _currentTime = _currentTime.addingTimeInterval(seconds)
    }
}
