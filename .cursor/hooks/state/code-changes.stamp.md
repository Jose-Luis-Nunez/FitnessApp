date: 2026-05-03T15:30:00
result: PASS
files_inspected: 12
findings: 1

## Scope

| # | File | Change Summary |
|---|------|----------------|
| 1 | `MuscleCategorySelectionViewModel.swift` | Continuation leak fix via `CheckedContinuationBox` + `NSLock` |
| 2 | `EnvironmentObjectContractTests.swift` | `.tags(.fast)` added |
| 3 | `FitnessProfile/Package.swift` | `FitnessTestSupport` dependency added |
| 4 | `TramDeparturesCardView.swift` | scenePhase handler simplified |
| 5 | `TramDeparturesViewModel.swift` | Auto-polling removed; single refresh on expand |
| 6 | `BMIServiceTests.swift` | `.tags(.fast)` added |
| 7 | `BVGTramServiceTests.swift` | `.tags(.fast)` added |
| 8 | `ProfileViewModelTests.swift` | `.tags(.fast)` added |
| 9 | `TramDeparturesCacheTests.swift` | `.tags(.fast)` added |
| 10 | `TramDeparturesViewModelTests.swift` | Tests rewritten for no-polling model |
| 11 | `ActiveSetViewModelTimerResetTests.swift` | Synchronous deterministic timer tests |
| 12 | `TimerServiceTests.swift` | Timeout increased, `waitUntil` kept for tick-loop only |

## Validation Report

### 1. Dead Code — PASS
- `startAutoRefresh`, `stopAutoRefresh`, `refreshTask`, `autoRefreshInterval`, `refreshInterval` — all removed from `TramDeparturesViewModel`. Grepped project-wide: zero remaining references.
- `toggleExpanded_pollingContinuesAcrossMultipleCycles` test — removed with the polling architecture, no stale references.
- No unused imports in any changed file. `CheckedContinuationBox` is used only by `MuscleCategorySelectionViewModel.startWorkoutObservation()`.

### 2. Reuse Opportunities — PASS
- No new UI components introduced in this diff. Changes are logic-layer (VM, tests).
- No inline weight/reps option generation, no `CapsuleToggleStyle` + Decimal pattern, no raw `VStack { Picker(.wheel) }`.

### 3. AppStyle Consistency — PASS
- No new hardcoded `Color`, `Font`, `Padding`, `CornerRadius`, or `Opacity` values introduced by this diff.
- Pre-existing `spacing: 2` and `spacing: 4` in `TramDeparturesCardView` are not from this changeset.

### 4. Utility Usage — PASS
- No weight formatting or date logic introduced. `TramDeparturesViewModel` continues to use its static `DateFormatter` (correct pattern — cached, not in computed property).

### 5. Layout Robustness — PASS
- No layout changes in this diff. `TramDeparturesCardView` changes are limited to the `.onChange(of: scenePhase)` handler — no visual/layout impact.

### 6. MVVM Violations — PASS
- The scenePhase handler in the View correctly delegates to `viewModel.onBecameActive()` — no business logic in `body`.
- `onBecameActive()` stale-check logic lives in the ViewModel (correct layer).

### 7. Navigation — N/A
- No navigation changes in this diff.

### 8. Architecture Principles — PASS
- **Unidirectional flow**: Maintained. View delegates to VM (`toggleExpanded`, `refresh`, `onBecameActive`), VM updates state, View re-renders.
- **Single source of truth**: `TramDeparturesViewModel` remains the single owner of departure state. No duplicated state introduced.
- **Explicit error handling**: `refresh()` uses proper `do/catch` with typed error handling. No `try?`.
- **Thread safety**: `CheckedContinuationBox` uses `NSLock` to protect the continuation from concurrent resume (task cancellation vs observation onChange). Correct double-resume prevention: `continuation` set to `nil` after extracting, then resume called outside the lock. Pattern is sound.
- **No polling anti-pattern**: The removal of `Task.sleep`-based polling in `TramDeparturesViewModel` is a move toward event-driven refresh (§13b compliant). The `onBecameActive()` stale-threshold check is an acceptable safety net.

### 9. Anti-Patterns — PASS
- No `try?` swallowing errors in changed files.
- No `DispatchQueue` / GCD usage.
- No Combine for new async work.
- No `DateFormatter` in computed properties (static `let` — correct).
- No `@StateObject` / `@ObservedObject` introduced.
- `try? await Task.sleep` in `TramDeparturesViewModelTests` (8 occurrences) — acceptable in test code for async settling, not a production anti-pattern.

### 10. Referential Integrity — PASS
- `stopAutoRefresh()` / `startAutoRefresh()` / `autoRefreshInterval` removed from VM — verified zero remaining callers project-wide.
- `onBecameActive()` now includes its own `isExpanded` guard (previously in the View's scenePhase handler) — the View caller is simplified to match.
- `TramDeparturesCardView.scenePhase` handler updated to remove `.inactive`/`.background` cases that called `stopAutoRefresh()`.
- `refreshInterval` init parameter removed — no external callers.
- All test files rewritten to match the new API surface.

### 11. Cleanup Sweep — PASS
- No `print()` statements in any changed file.
- No `TODO` / `FIXME` comments in any changed file.
- No commented-out code blocks.

### 12. State Propagation — PASS
- `isExpanded` remains `@Observable` `private(set)` — the `.onChange(of: scenePhase)` -> `onBecameActive()` chain is intact.
- `CheckedContinuationBox` in `MuscleCategorySelectionViewModel.startWorkoutObservation()`: the observation tracking chain (`ws.currentWorkout` change -> resume continuation -> `refreshExercises()`) is preserved from before. The new `withTaskCancellationHandler` + box pattern adds safe cancellation without breaking the propagation chain.
- No `@Published` restructuring in this diff.

### 13. Architecture Quality — PASS (partial applicability)
- **13a Single Source of Truth**: No new shared-state holders introduced.
- **13b Reactive over Polling**: The removal of `Task.sleep` polling from `TramDeparturesViewModel` is an explicit improvement here. The `MuscleCategorySelectionViewModel` continues to use `withObservationTracking` (correct pattern).
- **13c Protocol-Based Dependencies**: `BVGTramServicing`, `TramDeparturesCaching` — unchanged, testable via `MockService` / `MockCache`.
- **13d API Safety**: No new public mutable callbacks.
- **13e Testability**: Tests use mocks (MockService, MockCache, FakeClock). No real network/disk IO.
- **13f Consistency**: `CheckedContinuationBox` pattern matches the project's `withObservationTracking` + `withCheckedContinuation` convention (§13b). The box+lock approach is a safe improvement over a bare continuation that could be resumed twice on cancellation.
- **13g Root Cause vs Symptom**: The continuation leak fix addresses the root cause (double-resume on task cancellation) not just a symptom.
- **13h Duplicate Domain-State Holders**: No new `@State private var XViewModel` introduced. Pre-existing instances in `MuscleCategoryView.swift`, `TrainingView.swift`, `MuscleCategorySelectionView.swift` are unchanged.

### 14. SwiftData Predicate Anti-Patterns — N/A
- No `#Predicate` or `@Query` in the diff.

## Process Steps

- [x] P1. Removed/renamed symbols grepped project-wide — zero hits for `startAutoRefresh`, `stopAutoRefresh`, `refreshTask`, `autoRefreshInterval`, `refreshInterval`.
- [x] P2. No BUG-severity findings.
- [x] P3. No own-code findings requiring immediate fix.
- [ ] P4. **architecture-documentation.md requires update** — the `FitnessProfile/` entry still describes the old polling strategy (`Polling-Strategie (event-driven)`, `periodisches 60 s Refresh-Intervall`, `stoppt Polling bei .inactive/.background`, `Pin: toggleExpanded_pollingContinuesAcrossMultipleCycles`). This is now stale. **Finding severity: NIT** — documentation-only, no runtime impact. The update should be made in the same commit/task as the code changes.
- [x] P5. No new shared component/utility/token added — SKILL.md unchanged.
- [ ] P6. Tests not run (no xcodebuild in this subagent context). Logical trace: all changed test files compile against the new VM API surface; `ActiveSetViewModelTimerResetTests` use synchronous `FakeClock.advance(by:)` + `elapsedSeconds()` — deterministic; `TimerServiceTests.tickLoopPublishesElapsedSecondsWhenClockAdvances` retains `waitUntil` with `.minutes(1)` timeout for the async tick path only.
- [x] P7. Stamp written.

## Finding: Architecture Documentation Stale (NIT)

**File**: `.cursor/references/architecture-documentation.md`, line 34 (`FitnessProfile/` entry)

The `FitnessProfile/` paragraph still describes the old auto-polling architecture:
- "**Polling-Strategie (event-driven)**: Initial-Refresh on toggleExpanded; periodisches 60 s Refresh-Intervall solange aufgeklappt **und** App `.active`"
- "ScenePhase-Handler stoppt Polling bei `.inactive`/`.background`"
- "`Pin: TramDeparturesViewModelTests.toggleExpanded_pollingContinuesAcrossMultipleCycles`"

**Should read**: Manual-refresh model — single refresh on `toggleExpanded` (expand only), `RefreshActionButton` for user-initiated updates, `onBecameActive()` triggers refresh only when expanded and data is stale (>60 s). No periodic polling. ScenePhase handler only forwards `.active` to `onBecameActive()`.

## Residual Duplications

- `CheckedContinuationBox` exists only in `MuscleCategorySelectionViewModel.swift`. If additional `withObservationTracking` + `withTaskCancellationHandler` sites emerge, this box should be extracted to a shared utility. Currently single-use — no extraction needed.
- `StubURLProtocol` is duplicated between `BMIServiceTests.swift` and `BVGTramServiceTests.swift` (identical implementation). Pre-existing, not introduced by this diff. Follow-up candidate for extraction to `FitnessTestSupport`.
- No other residual duplications from this changeset.
