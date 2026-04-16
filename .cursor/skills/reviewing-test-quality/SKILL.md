---
name: reviewing-test-quality
description: >-
  Review unit and integration test quality in the FitnessApp project. Use when
  the user asks to review tests, check test quality, analyze test coverage,
  assess testability, find test gaps, or improve test structure. Covers
  Swift Testing (@Test/@Suite) and FitnessTestSupport conventions.
---

# Reviewing Test Quality

## Context

- **Test framework:** Swift Testing (`@Test`, `@Suite`, `#expect`, `Issue.record`)
- **Shared test utilities:** `FitnessTestSupport` package — `makeExercise()`, `MockAnalyticsStorage`, `StubAnalyticsStorage`, `waitUntil()`
- **Package structure:** Tests live under `Packages/<PackageName>/Tests/<PackageName>Tests/`
- **Build system:** Always use `xcodebuild` with `DEVELOPER_DIR` and `-skipMacroValidation` (see `build-and-test` rule)
- For domain models, services, and project structure see [architecture-documentation.md](../../references/architecture-documentation.md)

## Context Management

For reviews of multiple test files (3+), use a subagent/Task to perform the analysis in an isolated context. Return only the summary to the main conversation.

## Review Process

1. **Identify scope** — which test files to review (user-specified or all changed test files via `git diff`)
2. **Read the test files** and the production code they test
3. **Check each category** below and report findings with severity and line numbers
4. **Suggest fixes** with concrete code snippets
5. **Fix, don't just mention.** When reviewing your own tests, fix issues immediately.

## What to Check

### A: Test Style

| Pattern | Expected | Severity |
|---------|----------|----------|
| Test function without descriptive name | `@Test func <verb>_<scenario>_<expected>()` or `@Test("description")` | Warning |
| Tests not grouped in `@Suite` | Group related tests in `@Suite struct <Subject>Tests` | Warning |
| XCTest patterns (`XCTAssert*`) in Swift Testing files | Use `#expect`, `#require`, `Issue.record` | Critical |
| Missing `@MainActor` on tests touching `@MainActor` types | Add `@MainActor` to `@Suite` or individual `@Test` | Critical |
| Arrange-Act-Assert not clearly separated | Use blank lines or `// Arrange / Act / Assert` markers | Info |

### B: DRY — Shared Utilities

| Pattern | Expected | Severity |
|---------|----------|----------|
| Local `makeExercise()` factory | Use `FitnessTestSupport.makeExercise()` | Critical |
| Local `MockAnalyticsStorage` / `StubAnalyticsStorage` | Use from `FitnessTestSupport` | Critical |
| Local `waitUntil()` helper | Use `FitnessTestSupport.waitUntil()` | Critical |
| Duplicated mock/stub across test targets | Move to `FitnessTestSupport` | Warning |
| Missing `import FitnessTestSupport` when utilities are available | Add import | Warning |

### C: Assertion Strength

| Pattern | Expected | Severity |
|---------|----------|----------|
| `#expect(value != nil)` | `let unwrapped = try #require(value)` then assert on `unwrapped` | Warning |
| `#expect(array.count > 0)` | `#expect(array.count == <exact>)` or assert specific elements | Warning |
| `waitUntil` without `Issue.record` on timeout | Use shared `waitUntil()` which includes `Issue.record` | Critical |
| No negative test (only happy path) | Add test for invalid input, empty state, error case | Warning |
| `#expect(true)` or `#expect(false)` as placeholder | Replace with meaningful assertion | Critical |

### D: Coverage Gaps

Check the production code that the tests cover:

1. List all `public` / `internal` methods on ViewModels, Coordinators, UseCases, and Services
2. For each method, check if at least one test exercises it
3. Flag untested methods, prioritized by:
   - **Critical:** State-mutating methods (e.g. `completeExercise`, `editMore`, `resetExercise`)
   - **Warning:** Query methods (e.g. `getDailyWeightProgression`, `totalWeight`)
   - **Info:** Convenience/delegation methods

Also check for untested edge cases:
- Empty collections (no exercises, no analytics entries)
- Boundary values (weight = 0, sets = 0, reps = 0)
- Concurrent state changes (exercise completion during edit)

### E: Testability Hints (Production Code Issues)

Tests often reveal production code problems. Flag these:

| Pattern in Test | Production Code Problem | Severity |
|-----------------|------------------------|----------|
| Test uses `Container.shared` to set up dependencies | Production code has hard Container coupling — consider protocol injection | Warning |
| Test cannot mock a dependency (concrete class, no protocol) | Production type needs a protocol extraction | Warning |
| Test requires complex setup (> 10 lines of Arrange) | Production type has too many responsibilities — consider splitting | Info |
| Test uses `@Suite(.serialized)` without clear reason | Production code may have shared mutable state — investigate thread safety | Warning |
| Test initializes type with two different init signatures | Dual-Init pattern — consider consolidating or documenting intent | Info |
| Test uses real `Task.sleep` to exercise time-dependent production code | Production type lacks a clock/timer abstraction — introduce a protocol (e.g. `TimerClock`) + fake for deterministic tests | Warning |
| Test drives the production tick loop with a real-time sleep + tolerance (`>= N`) | Tick cadence is hardcoded — extract as initializer parameter so tests can shorten it | Warning |

#### E.1 — Diagnosing `.serialized`

A `@Suite(.serialized)` trait is legitimate only when production code shares mutable state across tests in that suite. Before keeping it, perform this check:

1. Grep the suite for `Container.shared` usage.
2. Grep the suite for `UserDefaults.standard` or other process-global mutables.
3. Grep for file-backed state under a shared path.

If **none** of these are present, `.serialized` is legacy and can be removed. Parallel execution then gives a 3–5× run-time speedup within that suite at zero risk. If any are present, do NOT remove `.serialized` without first migrating the production code to constructor-injected dependencies (see `reviewing-code-changes` section 13c).

### F: Test Maintenance

| Pattern | Expected | Severity |
|---------|----------|----------|
| `Container.shared.reset()` not called in init/deinit | Add to `init()` of test suite to ensure isolation | Critical |
| Tests depend on execution order | Use `.serialized` trait explicitly or make tests independent | Critical |
| Magic numbers in assertions without context | Use named constants or comment explaining expected value | Warning |
| Test file > 300 lines without suite splitting | Split into focused `@Suite` structs | Info |

### G: Performance Smells

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

When production code reads `Date()` or drives a loop with `Task.sleep`, introduce a protocol (see `TimerService` / `TimerClock`). Tests inject a `FakeClock` that advances synchronously. Never test a 1 s `Task.sleep` with a 1 s real-time wait — that measures Foundation, not your code.

Pattern:

```swift
public protocol TimerClock: Sendable { func now() -> Date }
public struct SystemTimerClock: TimerClock {
    public init() {}
    public func now() -> Date { Date() }
}

// Production
public init(clock: any TimerClock = SystemTimerClock(), tickInterval: Duration = .seconds(1)) { … }

// Test
let clock = FakeClock()
let sut = Service(clock: clock, tickInterval: .milliseconds(5))
clock.advance(by: 1)
try await waitUntil { sut.publishedValue == 1 }
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

## Report Format

Group findings by category. For each finding:

```
**[Category:Severity]** `TestFile.swift:LINE`
  Found: <what the test does wrong>
  Fix: <specific replacement with code snippet>
```

End with a summary:

```
## Summary
- A (Test Style): N findings (N critical, N warning, N info)
- B (DRY): N findings
- C (Assertion Strength): N findings
- D (Coverage Gaps): N untested methods
- E (Testability Hints): N production code issues
- F (Test Maintenance): N findings
- G (Performance Smells): N findings (parallelism ratio per package)

Overall: PASS / NEEDS WORK / CRITICAL ISSUES
```

## Running Tests After Review

After fixing test issues, run the affected package tests to verify:

```bash
cd ~/Documents/repo/FitnessApp/Packages/<Package> && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild test -scheme <Package> -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
-skipMacroValidation 2>&1 | tail -30
```

Write a test stamp to `.cursor/hooks/state/test-execution.stamp.md` after successful execution.
