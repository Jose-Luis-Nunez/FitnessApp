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
- For domain models, services, and project structure, read only the relevant
  heading in `.claude/references/architecture-documentation.md`

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

If **none** of these are present, `.serialized` is legacy and can be removed. Parallel execution then gives a 3–5× run-time speedup within that suite at zero risk. If any are present, do NOT remove `.serialized` without first migrating the production code to constructor-injected dependencies (see `reviewing-code-changes/references/state-services-review.md`).

#### E.2 — Callback Fidelity (Mock-Vertragsbruch)

When tests instantiate a service with closure parameters directly (instead of via the production factory/cache), the test closures must perform **all** side-effects the production wiring performs. Otherwise tests "pass" while the real write path is never exercised — exactly the bug class we are looking for.

##### Smell

```swift
// In Tests:
let coordinator = TrainingCoordinator(
    findCategory: { _ in group },
    onExerciseUpdate: { _, _ in storage.bumpVersion() },  // breaks the production contract
    onExerciseReset:  { _, _ in }
)

// In Production (TrainingCoordinatorCache):
let coordinator = TrainingCoordinator(
    findCategory: { _ in group },
    onExerciseUpdate: { exercise, category in
        managementService.updateExercise(exercise, category: category)  // missing in test
    },
    onExerciseReset: { exercise, category in
        managementService.resetExercise(exercise, category: category)
    }
)
```

The test "proves" the UI reacts to `bumpVersion` — not that `updateExercise` is ever called. The "missing write path" bug class stays invisible. Real example: `MuscleCategorySelectionViewModelTests.swift`.

##### Search Pattern

```bash
# Find test-side service constructors with closures:
rg -n 'TrainingCoordinator\(|XStorageService\(' Packages/*/Tests --glob '*.swift' -A5 \
  | rg -B1 'on\w+: \{'

# Compare against production wiring:
rg -n 'TrainingCoordinator\(' Packages/*/Sources --glob '*.swift' -A8
```

If the test closure makes **fewer** service calls than production → smell.

##### Fix Options

1. **Shared test fixture** — extract production wiring into a test-helper module (e.g. `TrainingCoordinatorCache(storage: testStorage, management: testManagement)`) and use it instead of hand-rolled closures.
2. **Real coordinator-cache in tests** — when the cache is `@MainActor` and has no heavy dependencies, use it directly.
3. **Integration via real container** — in-memory `ModelContainer` + production `ExerciseManagementService` + `TrainingCoordinatorCache`.

##### Acceptance Criterion

Every `on*`-closure in test setup must either:
- make exactly the same service calls as the production counterpart, or
- include a comment `// MARK: mirrors X.swift line Y` referencing the production wiring, or
- run via a shared fixture that guarantees parity.

#### E.3 — State Pre-Priming (test writes what production should write)

##### Smell

```swift
for _ in 0..<exercise.sets { coordinator.completeSet() }

var completed = exercise
completed.isCompleted = true
mock.exercisesByCategory[.arms] = [completed]   // test pre-writes the end state

coordinator.finishExercise()                    // whatever happens here is irrelevant —
                                                // the mock is already "done"

#expect(cardVM.exercise.isCompleted)
```

The test pre-primes the expected end state before the call under test runs. Production may be entirely broken and the test still passes.

##### Real example (caught in this codebase)

`Packages/FitnessExercise/Tests/FitnessExerciseTests/MuscleCategoryViewModelTests.swift:232–237`:

```swift
completed.isCompleted = true
storage.savedExercises[.arms] = [completed]   // pre-write the end state

vm.refreshExercises()

#expect(vm.exercises.first?.isCompleted == true)   // tautology
```

What the test claims to verify: "after `refreshExercises()`, the VM reflects completion."
What it actually verifies: "`refreshExercises()` reads from `savedExercises`" — which was hand-set one line above. If the production path that *should* have written `[completed]` to storage (e.g. `FinishExerciseUseCase`) is broken, this test stays green. This is one of the test-shapes that let Bug 2 (category progress not refreshing) ship.

The fix below shows the corrected shape for this exact case.

##### Search Pattern

```bash
rg -n 'exercisesByCategory\[\..+\]\s*=' Packages/*/Tests --glob '*.swift' -B2 -A5 \
  | rg -B5 'finishExercise\(\)|completeSet\(\)'
```

Any sequence `mock.X = expectedEndState` directly before `coordinator.action()` is suspect.

##### Fix

Tests must not "help" the domain path. Real setup:

```swift
// Before: domain state as it would be at the start of the action
mock.exercisesByCategory[.arms] = [activeExercise]

// Action:
coordinator.finishExercise()

// After: observe mock effects (which updateExercise calls came in?)
#expect(mock.updateExerciseCalls.contains { $0.exercise.id == activeExercise.id })
#expect(mock.updateExerciseCalls.last?.exercise.isCompleted == true)
```

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

### H: Snapshot Tests

Snapshot tests guard the visual contract of `public` Views in `FitnessUI` and `FitnessPersistenceUI`. They live in:

- `Packages/FitnessUI/Tests/FitnessUITests/SnapshotTests.swift`
- `Packages/FitnessPersistenceUI/Tests/FitnessPersistenceUITests/IdleCardSnapshotTests.swift`

Recorded baselines are PNGs under each package's `Tests/<Package>Tests/__Snapshots__/<TestFileName>/`.

#### H.1 — Conventions

```swift
@Suite("<ViewName> — Snapshots", .tags(.snapshot))
@MainActor
struct <ViewName>SnapshotTests {

    @Test func <variant>() {
        let view = <ViewName>(/* minimal valid init */)
        assertSnapshot(of: view, named: "<file-friendly-variant>", size: CGSize(width: 100, height: 100))
    }
}
```

- **Suite name pattern:** `"<ViewName> — Snapshots"` (em-dash separator). Tag every snapshot suite with `.tags(.snapshot)` so they can be filtered/skipped as a group.
- **`@MainActor` on the suite**, not the test — Views must be constructed on the main actor.
- **`named:` argument** is the file-name fragment for the PNG. Use kebab-case to match the convention seen in `__Snapshots__/SnapshotTests/*.png` (e.g. `idle-styled-reset`, `with-weight`, `expanded`).
- **`size:`** — 100×100 for small leaf components (icons, buttons, chips), `CGSize(width: 360, height: <natural>)` for cards or full-width components. Avoid arbitrary frames that hide overflow.
- One `@Test` per **meaningful** visual variant, not per prop combination. Three to five variants (default, edge case, interaction state) is healthy; ten variants of the same View is a smell.

#### H.2 — Where snapshot tests are required vs optional

| View kind | Snapshot required? |
|---|---|
| New `public struct …: View` in `FitnessUI/Sources/` | **Yes** — at least one default-state snapshot. |
| New `public struct …: View` in `FitnessPersistenceUI/Sources/` | **Yes** — typically a full-card snapshot via the existing `IdleCardSnapshotTests.swift` patterns. |
| Thin wrapper (1:1 delegation to a covered View) | Optional. Note exception in the diff. |
| `internal` / `fileprivate` Views | Optional — covered transitively by the public View that embeds them. |
| Pure non-View types (modifiers, helpers, data) | No. |

#### H.3 — When to re-record a baseline

Re-record when *and only when* the visual change is **intentional**:

- new color/gradient/font token
- changed layout proportions (sizes, paddings, offsets)
- added/removed visual layer (halo, ring, edge indicator, gradient)
- corner radius / opacity / shadow change

Do **not** re-record to "make a failing test pass" without auditing the diff. A snapshot failure on a refactor that *should* be visually equivalent is a real regression — investigate before re-recording.

Re-record flow:

```bash
# Re-record by setting the env on the package test command
DEVELOPER_DIR=… RECORD_SNAPSHOTS=1 xcodebuild test -scheme FitnessUI -destination '…' …
git add Packages/FitnessUI/Tests/FitnessUITests/__Snapshots__/
```

Or, for a single suite, temporarily flip `record: true` on the failing `assertSnapshot(...)` call, run, commit the new png, revert the `record:` change.

#### H.4 — Smells

| Smell | Why it hurts | Fix |
|---|---|---|
| Snapshot test exists but no PNG checked in | First run records on the developer's machine and fails CI. | Run with `RECORD_SNAPSHOTS=1` once; commit the baseline PNG alongside the test. |
| `@Test` per prop combination (12+ tests for one View) | Every visual tweak forces re-recording dozens of baselines. | Collapse to 3–5 meaningful variants; let unit tests cover prop logic. |
| Re-recorded baseline in a "no-visual-change" refactor PR | The refactor was not pixel-equivalent — a real regression hidden as a re-record. | Stop, diff the old/new PNG visually (`git diff -- '**/*.png'` or open both), explain in PR description, or revert. |
| Snapshot of a View that owns dynamic data (date, random, animated) | Flaky baseline. | Inject the dynamic input as a parameter; pass a fixed value in the snapshot. |
| Missing `@MainActor` → compiler / runtime error | n/a | Add `@MainActor` on the `struct`. |

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
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode-beta.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode-beta.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild test -scheme <Package> -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0' \
-skipMacroValidation 2>&1 | tail -30
```

Use the generated `FitnessTraining-Package` scheme when `<Package>` is
`FitnessTraining`; that package exposes multiple products and its product
scheme has no test action.

Write a test stamp to `.claude/hooks/state/test-execution.stamp.md` after successful execution.
