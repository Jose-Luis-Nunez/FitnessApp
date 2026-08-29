# E: Testability Hints (Production Code Issues)

Production-code problems that tests reveal.

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
