---
name: reviewing-code-changes
description: >-
  Review Swift/SwiftUI code and validate changes. Checks for architecture
  violations, hardcoded styling, dead code, missed reuse, AppStyle consistency,
  layout robustness, MVVM compliance, referential integrity, and anti-patterns.
  Use when the user asks to review code, audit styling, verify architecture,
  validate changes, or clean up after refactoring.
---

# Reviewing Code Changes

## Context

For domain models, services, shared components, utilities, AppStyle tokens, and project structure see [architecture-documentation.md](../../references/architecture-documentation.md).

## Context Management

For reviews of large files (500+ lines) or multiple files (2+), use a subagent/Task to perform the analysis in an isolated context. Return only the summary to the main conversation. This keeps the primary context window clean for follow-up work.

## When to Run

Activate this skill after any of these events:
- Refactoring (rename, extract, move, delete)
- Adding or removing a feature, view, or service
- Large multi-file edits
- User asks to "review", "check conventions", "audit styling", "verify architecture compliance"
- User asks to "check", "verify", "validate", or "clean up" changes

## Review Process

1. **Identify scope** — use `git diff` (or the staged/unstaged diff) to identify changed files, then inspect each. For user-requested reviews, inspect the files the user specifies.
2. **Check each category** below and report violations with line numbers.
3. **Suggest fixes** using the correct AppStyle token or shared component.
4. **Fix, don't just mention.** When reviewing your own code (e.g. user asks "ist die Lösung gut?"), do not merely describe known weaknesses — fix them immediately. Mentioning a problem without resolving it wastes a round-trip.

## Validation Checklist

Work through each category. For each failing item, cite the concrete file and line.

### 1. Dead Code

Search changed files and their immediate dependents for:

- **Unused imports** — `import` statements with no usage in the file
- **Unused functions/methods** — defined but never called (search project-wide)
- **Unused properties** — `let`/`var` declarations with no read access
- **Orphaned files** — files that were part of a deleted feature but not removed
- **Stale NavigationDestination cases** — enum cases no longer referenced
- **Cross-feature orphans** — when deleting a feature, also check:
  - Coordinators that orchestrate it (e.g. `TrainingCoordinator` for Training)
  - Caches that store its state (e.g. `SessionTrainingCache`)
  - Shared Components built exclusively for it (e.g. `TrainingSessionComponent`)
  - Callbacks/delegates referencing it (e.g. `TrainingCallbacks`)
  - `UIOverlayState` flags tied to the deleted feature
- **Enum case coverage** — when adding/removing an enum case, grep for all `switch`, `if case`, `guard case` on that type

How to check: For each removed or renamed symbol, grep the project for remaining references. Zero hits = dead code. For deleted features, also grep for the feature name prefix (e.g. "Training") across all folders.

### 2. Reuse Opportunities

Compare new/changed code against existing shared components and utilities:

| If you see | Consider using |
|---|---|
| Custom chip with background + stroke | `MetricChipView` |
| Full-screen sheet with header + save | `WorkoutFormSheet` |
| Expandable card with greenBlack fill | `AnalyticsDetailSection` |
| Bottom sheet with backdrop + grabber | `ExercisePickerSheetModifier` |
| Cancel/Save button row | `ExercisePickerActionButtons` |
| Wheel pickers for sets/reps/weight | `ExerciseWheelPickerRow` |
| Styled text input in a sheet | `ExercisePickerInputField` |
| Manual weight string formatting | `WeightFormatter.displayWeight(_:)` |
| Manual date logic in analytics | `AnalyticsDateHelper` |

### 3. AppStyle Consistency

Scan changed files for hardcoded values that should use tokens:

| Pattern | Should Be |
|---------|-----------|
| `Color(hex: "...")` | `AppStyle.Color.<token>` |
| `Color.white`, `.red`, `.gray` | `AppStyle.Color.white`, add token if missing |
| `.font(.system(size: N, weight: .W))` | `AppStyle.Font.<token>` |
| `.padding(N)`, `.padding(.edge, N)` | `AppStyle.Padding.<token>` |
| `.cornerRadius(N)` | `AppStyle.CornerRadius.<token>` |
| `.opacity(N)` | `AppStyle.Opacity.<token>` |

If no matching token exists, recommend adding one to `AppStyle.swift` with a semantic name.

```swift
// BAD
.font(.system(size: 14, weight: .semibold))
.foregroundColor(Color(hex: "#088177"))
.padding(.horizontal, 18)
.cornerRadius(12)
.opacity(0.55)

// GOOD
.font(AppStyle.Font.tileLabel)
.foregroundColor(AppStyle.Color.green)
.padding(.horizontal, AppStyle.Padding.horizontal)
.cornerRadius(AppStyle.CornerRadius.defaultButton)
.opacity(AppStyle.Opacity.overlayBackdrop)
```

### 4. Utility Usage

- Weight formatting without `WeightFormatter.displayWeight(_:)` (look for `String(format: "%.1f"` + `replacingOccurrences` or manual `"kg"` concatenation)
- Date logic in analytics without `AnalyticsDateHelper` (look for `Calendar.current`, `DateFormatter` in analytics files)

### 5. Layout Robustness

- Magic number offsets in `.alignmentGuide`, `.offset`, or `.padding` used to visually position elements relative to other containers -> group elements in the same `VStack`/`HStack` instead
- Short label texts (< 10 chars) without `.fixedSize()` that may line-break on small screens
- Related UI elements (e.g. icon + chevron) placed in separate containers when they belong in the same row -> move into shared `HStack`
- Tap targets have >= 8pt spacing and `.contentShape(Rectangle())`
- Labels/values in a row share the same vertical alignment
- Separator heights and padding consistent across all instances

### 6. MVVM Violations

- Business logic (data manipulation, service calls, storage access) in View `body` or computed view properties
- ViewModel not using `ObservableObject` + `@Published`
- View creating services directly instead of going through ViewModel

### 7. Navigation

- Navigation via manual `NavigationLink` instead of `navigationPath.append(NavigationDestination.<case>)`
- Missing `NavigationDestination` case for new screens

### 8. Architecture Principles

Check against these principles (based on production architecture research: Uber, Airbnb, Lyft, Square, Revolut, Kickstarter, Spotify, Pinterest):

- **Unidirectional Data Flow** — User Action -> ViewModel -> Use Case -> Repository -> Store -> ViewModel -> View. No two-way bindings between layers.
- **Single Source of Truth** — Every piece of data has exactly one owner. No duplicated state across multiple ViewModels or caches.
- **Explicit Error Handling** — No `try?` swallowing errors. Errors propagate to meaningful handlers with user feedback or logging.
- **Thread Safety by Design** — Actors for storage/sync, `@MainActor` for UI. No unprotected shared mutable state, no GCD/DispatchQueue.
- **Offline-First** — Local database is source of truth. Views never touch network directly.

### 9. Anti-Patterns (always flag)

| Anti-Pattern | Why it breaks |
|---|---|
| `try?` swallowing errors | Silent data loss |
| JSON files as database | No queries, migrations, integrity |
| Multiple VMs sharing same data source | Stale UI, race conditions |
| ViewModel calling network/persistence directly | Layer violation |
| Singletons for shared state | Hidden dependencies |
| `@StateObject`/`@ObservedObject` in new code | Loses property-level observation |
| GCD / DispatchQueue | Legacy, no structured cancellation |
| Combine for new async work | Being replaced |
| `DateFormatter` in computed properties | 2-5ms per render |
| `ForEach` with index iteration | O(n) diffing |
| Unprotected shared mutable state | Race conditions |
| `@Environment` not re-injected in sheets | Runtime crashes |

### 10. Referential Integrity

- New views registered in `NavigationDestination` if navigable
- Deleted views removed from `NavigationDestination`
- Service API changes reflected in all calling ViewModels
- Model property changes reflected in all consumers
- New model fields on `Codable` types must be optional or have a default value (existing JSON data lacks the field)
- Enum case additions handled in every `switch` statement project-wide

### 11. Cleanup Sweep

- Resolve or remove stale `TODO` / `FIXME` comments in changed files
- Remove commented-out code blocks (dead weight after refactoring)
- Verify `print()` / debug statements are removed

### 12. State Propagation (after ViewModel/Coordinator refactoring)

When `@Published` properties are restructured (moved, renamed, wrapped in structs):

- **Combine subscribers:** Grep for `$propertyName`. If the property became computed (bridging to a nested `@Published` struct), the `$` prefix won't compile. Subscribers must observe the underlying struct.
- **Cached ViewModel sync:** Cached VMs must use a dedicated sync method (e.g. `syncExercise(_:)`) that suppresses `onUpdate` callbacks. Direct `.exercise = updated` causes re-entrant loops.
- **Equatable traps:** If a model has id-only `Equatable`, guards like `exercise != oldValue` miss content changes. Verify sync guards use `isContentEqual(to:)`.
- **objectWillChange suppression:** `didSet` guards on `@Published` must not silently swallow content-level changes due to id-only equality.
- **Conditional View rendering chain** — trace and verify each link:
  1. **Mutation**: The property is actually set (e.g. `isCompleted = true`)
  2. **@Published fires**: The mutation is on a `@Published` property (not a computed one)
  3. **objectWillChange**: Not suppressed by a `didSet` guard using id-only equality
  4. **View body**: The `@ObservedObject` re-evaluates its `body`
  5. **Condition switches**: The `if/else` branch changes to render the correct sub-view
  Any broken link = stale UI.

After completing the state propagation checks, run or trace tests:
- **If xcodebuild is available**: Run unit tests to verify nothing broke
- **If not available**: Perform a logical trace for each changed `@Published` property through the chain above and document your reasoning

### 13. Architecture Quality (after new services, protocols, caches, coordinators, or shared state)

Run this section when the change introduces or modifies: a service, protocol, cache, coordinator, shared state object, ViewModel with injected dependencies, or reactive observation pattern. Skip for pure UI/View changes.

Check every item. For each failing item, cite the concrete file and line. **Fix findings immediately** — do not just report them.

#### 13a. Single Source of Truth

- Shared mutable state (training status, exercise data, workout selection) has exactly **one** owner.
- No duplicated instances of the same coordinator/cache/state across views.
- Views that need the same data read from the same shared instance (via DI, not local `@State` copies).

#### 13b. Reactive over Polling

- No `Task.sleep` polling loops to detect state changes on `@Observable` objects.
- Use `withObservationTracking` + `withCheckedContinuation` for programmatic observation outside SwiftUI views.
- `onChange(of:)` / `onAppear` are acceptable only as safety nets, not as primary state propagation.

#### 13c. Protocol-Based Dependencies

- Every service/cache dependency used by a ViewModel has a protocol.
- Factory registrations return the **protocol type**, not the concrete class.
- ViewModels accept dependencies via init (constructor injection) or `@Injected` with protocol types.
- A mock for each protocol can be written in <20 lines.

```swift
// BAD — concrete dependency, not testable
class ProfileViewModel: ObservableObject {
    private let bmiService = BMIService()
}

// GOOD — injected via protocol
class ProfileViewModel: ObservableObject {
    @Injected(\.bmiService) private var bmiService: BMIProviding
}
```

#### 13d. API Safety

- Closures/callbacks on shared objects are not `public var` (prevents accidental overwrite).
- Mutable callbacks use explicit setter methods (`setOnX(_:)`) to signal intent.
- Core callbacks (`onUpdate`, `onReset`) that the owner sets are `private let`.

#### 13e. Testability

- Every new ViewModel has a test-friendly init that accepts mocked dependencies.
- At least one test exists for each reactive observation (training-end triggers refresh, workout-change triggers category update, etc.).
- Tests use mocks — not real storage/UserDefaults/disk IO.

#### 13f. Consistency

- The same observation pattern is used everywhere (don't mix polling and `withObservationTracking` for the same kind of change).
- Protocol naming follows project convention: `*Storing`, `*Managing`, `*Caching`.
- All protocols live in `FitnessCore` (cross-package boundary types).

#### 13g. Root Cause vs. Symptom

Before implementing a fix, determine where it belongs:

1. **Ask:** "Is this a data-flow problem or a UI-display problem?"
   - Data-flow -> fix in Use Case, Service, or Coordinator
   - UI-display -> fix in View (only after confirming the data layer is correct)

2. **Ask:** "If a new entry point (Deep Link, Live Activity, test) triggers the same action, does my fix still work?"
   - Yes -> root cause fix (logic layer)
   - No -> symptom fix (UI guard) — move the logic down

3. **Never** add a UI guard (`if` / `guard` in a View's `onStart` / `onTap`) to protect against a business-logic gap. The guard belongs in the Use Case or Coordinator that owns the state.

4. **Always** write at least one integration test that verifies the new behavior through the Coordinator (not just the Use Case in isolation). If the fix involves state transitions, test the full sequence: setup -> action -> assert state + side effects.

When fixing a bug involving stale UI or missing updates:

- Verify the fix addresses the **data flow gap** (root cause), not just adding more observation triggers or sleep delays (symptom fix).
- Observation of state transitions (e.g. `isTrainingActive`) should not be used as a proxy for domain events (e.g. "exercise was completed"). Prefer explicit domain event signals (e.g. `lastCompletedExercise`).
- If a fix requires observing **more than 2 properties** to detect a single logical event, it is likely a symptom fix — introduce a dedicated event property instead.
- After a bug fix, ask: "If a new similar event is added tomorrow, does the fix still work, or do I need to add another observed property?" If the latter, the fix is fragile.

## Output

### 1. Full Report (in agent response)

Print the detailed report in your response so the user can see all findings:

```
## Code Review Report

**Files inspected:** N files

### Dead Code
- `FileName.swift:LINE` — `unusedFunction()` has 0 references, safe to remove

### Missed Reuse
- `FileName.swift:LINE` — reimplements chip pattern, use `MetricChipView` instead

### Style Violations
- `FileName.swift:LINE` — hardcoded `.padding(16)`, use `AppStyle.Padding.card`

### Layout Issues
- `FileName.swift:LINE` — short label without `.fixedSize()`

### MVVM Violations
- `FileName.swift:LINE` — service call in View body, move to ViewModel

### Navigation Issues
- `FileName.swift:LINE` — manual NavigationLink, use router

### Architecture Principles
- `FileName.swift:LINE` — `try?` swallowing error, use do/catch

### Referential Issues
- `NavigationDestination` missing case for new `FeatureView`

### Cleanup
- `FileName.swift:LINE` — stale TODO from resolved task

### State Propagation
- `FileName.swift:LINE` — `$computedProperty` subscriber will not compile after refactoring

### Architecture Quality
- `FileName.swift:LINE` — `ExerciseManagementService` used as concrete type, needs protocol

**Summary:** N dead code, N reuse, N style, N layout, N MVVM, N navigation, N architecture, N referential, N cleanup, N state, N quality items found.
```

### 2. Stamp file (for the hook)

Write a **minimal** stamp to `.cursor/hooks/state/validation-stamp.md` so the grind-loop hook knows validation ran. This file is a checkpoint, not a report — it gets overwritten each run.

When triggered by a user review request (not post-change validation), the stamp is optional.

```
date: 2026-04-11T14:30:00
result: PASS
files_inspected: 5
findings: 3
```

## Architecture Sync

When you edit Swift files, check if the change affects any of the items below. If it does, update `.cursor/references/architecture-documentation.md` in the **same commit/task** — do not defer.

### Trigger Map

| What changed | Section to update in `architecture-documentation.md` |
|---|---|
| `Shared/Design/AppStyle.swift` — new/renamed/removed token | **AppStyle Tokens** — add/rename/remove the token entry |
| New file in `Shared/View/`, `Shared/Design/`, `Shared/Components/` | **Shared Components** table — add row with component, file, purpose |
| Deleted shared component | **Shared Components** table — remove row |
| New/changed/deleted service | **Services** section — update API surface |
| New/changed/deleted model in `Core/Model/` | **Domain Models** section — update fields |
| New/changed `NavigationDestination` case | **Navigation** section — update enum listing |
| New feature folder under `Features/` | **Feature Map** tree — add entry |
| Deleted feature folder | **Feature Map** tree — remove entry |
| New utility in `Shared/Utilities/` | **Utilities** section — add entry |
| Changed coordinator or state object | **State & Navigation** section — update |
| New/deleted test suite or test file under `Packages/*/Tests/` | **Feature Map** tree — update test inventory |
| New/deleted shared test utility in `FitnessTestSupport` | **Feature Map** tree — update `FitnessTestSupport` entry |
| New/deleted test file under `FitnessAppTests/` | **Feature Map** tree — update test inventory |

### How to Update

1. Read `.cursor/references/architecture-documentation.md`
2. Find the relevant section from the trigger map
3. Apply the minimal change (add/edit/remove the affected entry)
4. Do not rewrite unrelated sections

### Skill References

If the change affects what the skills check for, update the skill's `SKILL.md` as well:

- New shared component -> add detection pattern to "Reuse Opportunities" table (this skill)
- New utility -> add usage check to "Utility Usage" list (this skill)
- New AppStyle token category -> add pattern to "AppStyle Consistency" table (this skill)
