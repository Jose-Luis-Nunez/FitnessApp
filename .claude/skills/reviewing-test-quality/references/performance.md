# G: Performance Smells

Slow tests are not just an inconvenience — they are a signal. Before accepting a slow test or "just making CI faster", diagnose the root cause using this matrix.

#### G.1 — The three legitimate reasons for `Task.sleep` in a test

| Purpose | Example | Verdict |
|---------|---------|---------|
| **Negative assertion** — "after N ms, state has NOT changed" | `sleep(200ms); #expect(!isCompleted)` | **Keep.** The sleep IS the test. |
| **Observation-setup race** — `@Observable` subscription activates only after first read | Subscribe / sleep / mutate / wait | **Keep with comment.** Document why the sleep cannot be replaced. Ideally fix the observation-setup in the VM. |
| **Waiting for async propagation after an event** | `event(); sleep(100ms); #expect(state)` | **Remove.** Use `waitUntil { state == expected }` instead. |

Redundant sleep after `waitUntil` is always removable:

```swift
// BAD — sleep is redundant, waitUntil already observed the causal chain
coordinator.startTraining(for: ex)
try await waitUntil { coordinator.activeSessions[ex.id] != nil }
try await Task.sleep(for: .milliseconds(100))  // ← delete
#expect(vm.exercises.count == 2)

// GOOD — assert on the observable state directly
coordinator.startTraining(for: ex)
try await waitUntil { coordinator.activeSessions[ex.id] != nil }
#expect(vm.exercises.count == 2)

// BETTER — wait on the observable state itself
coordinator.startTraining(for: ex)
try await waitUntil { vm.exercises.count == 2 }
```

#### G.2 — Clock abstraction for time-dependent code

When production code derives state from `Date()`, introduce a clock protocol
(see `TimerService` / `TimerClock`) and test the state transition synchronously.
Never test a 1 s `Task.sleep` with a 1 s real-time wait — that measures the
scheduler, not the domain contract.

Do not add a separately injectable ticker merely to exercise a simple internal
publish loop. Test that loop only when its cadence is itself a critical product
contract. Otherwise cover start, stop, reset, and elapsed-time calculation via
the fake clock and leave scheduler behavior to the platform.

Pattern:

```swift
public protocol TimerClock: Sendable { func now() -> Date }
public struct SystemTimerClock: TimerClock {
    public init() {}
    public func now() -> Date { Date() }
}

// Production
public init(clock: any TimerClock = SystemTimerClock()) { … }

// Test
let clock = FakeClock()
let sut = Service(clock: clock)
clock.advance(by: 1)
#expect(sut.elapsedSeconds() == 1)
```

This gives **deterministic** coverage of the same production path, orders of magnitude faster than real-time sleeps.

#### G.3 — Parallelisation diagnostic

Swift Testing parallelises `@Test` functions by default unless suppressed by `.serialized`. A healthy suite has a parallelisation ratio (sum of per-test durations ÷ wall-clock) of 20–40× on Apple Silicon. Compute it from the package log:

```bash
sum=$(grep -E "^✔ Test .* passed after [0-9.]+ seconds" LOG | \
      sed -E 's/.*after ([0-9.]+) seconds.*/\1/' | awk '{s+=$1} END {print s}')
wall=$(grep -E "^✔ Test run with" LOG | sed -E 's/.*after ([0-9.]+) seconds.*/\1/')
echo "ratio=$(echo "$sum / $wall" | bc -l)"
```

Ratio interpretation:
- **>20×** — healthy, nothing to do.
- **5–15×** — suppressed parallelism somewhere. Look for `.serialized`, shared `ModelContainer`, or process-global state.
- **<5×** — either too few tests for meaningful signal, or a single slow test dominates (look at the top-5 slowest tests in the log).
