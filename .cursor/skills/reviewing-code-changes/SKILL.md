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

## Pre-Flight Checklist

Before reporting the review as complete, verify every item.
Mark each as PASS / FAIL(n) / N/A where n = number of findings.

### Validation Categories
- [ ] 1. Dead Code — unused imports, functions, properties grepped
- [ ] 2. Reuse Opportunities — compared against shared components table
- [ ] 3. AppStyle Consistency — no hardcoded Color/Font/Padding/CornerRadius/Opacity
- [ ] 4. Utility Usage — WeightFormatter, AnalyticsDateHelper used where applicable
- [ ] 5. Layout Robustness — no magic offsets, tap targets >= 8pt, alignment checked
- [ ] 6. MVVM Violations — no business logic in View body
- [ ] 7. Navigation — NavigationDestination cases match navigable views
- [ ] 8. Architecture Principles — unidirectional flow, single source of truth, explicit errors, thread safety
- [ ] 9. Anti-Patterns — every item in the anti-pattern table checked
- [ ] 10. Referential Integrity — all consumers of changed APIs updated
- [ ] 11. Cleanup Sweep — no print(), TODO/FIXME, commented-out code
- [ ] 12. State Propagation — @Published chain traced, tests run
- [ ] 13. Architecture Quality — 13a–13g sub-checks (skip if pure UI change)

### Process Steps
- [ ] P1. Removed/renamed symbols grepped project-wide (zero hits = dead code)
- [ ] P2. BUG-severity findings fixed immediately (not just reported)
- [ ] P3. Own-code findings fixed immediately ("fix, don't just mention")
- [ ] P4. architecture-documentation.md updated if trigger map matched
- [ ] P5. This SKILL.md updated if new shared component/utility/token category added
- [ ] P6. Tests run for affected packages
- [ ] P7. Stamp written to code-changes.stamp.md

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
  - Caches that store its state (e.g. `TrainingCoordinatorCache`)
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
| Overlay sheet with backdrop + grabber + dismiss | `OverlaySheetContainer` (full chrome) |
| Bottom sheet inner styling only | `ExercisePickerSheetModifier` |
| Cancel/Save button row | `ExercisePickerActionButtons` |
| Wheel pickers for sets/reps/weight | `ExerciseWheelPickerRow` |
| **Single wheel column** (Title + `Picker(…).pickerStyle(.wheel)` + `.clipped()`) for a typed value | `FitnessWheelPickerColumn<Value: Hashable, Label: View>` |
| **Decimal-Toggle** next to a weight wheel (label + `CapsuleToggleStyle` filtering half-steps) | *extract to `WeightDecimalToggle` in FitnessUI — 5+ inline copies exist as of Apr 2026* |
| **Inline `for i in …` building a `[String]`/`[Double]` of weight options** (integer + 0.5 steps) | `WeightOptionsGenerator.exerciseWeightOptions` / `.trainingWeightOptions` — or add a typed variant there |
| Styled text input in a sheet | `ExercisePickerInputField` |
| Manual weight string formatting | `WeightFormatter.displayWeight(_:)` |
| Manual date logic in analytics | `AnalyticsDateHelper` |

**Beyond-the-table duplication check.** The table above is not exhaustive. Before concluding §2, also run a structural-duplication pass:

1. Grep the changed files for any `for i in … { options.append(…) }` / `values.append(…)` loop that builds weight/reps/sets options inline. If present → consolidate into `WeightOptionsGenerator`.
2. Grep for any `Toggle("", isOn: …)` paired with a `CapsuleToggleStyle` **+** a `Text("Decimal")` (or similar single-word label). Three+ matches project-wide → extract.
3. Grep for any `VStack { Text(title)…; Picker(…) { ForEach(…) { Text(…).tag(…) } }.pickerStyle(.wheel).clipped() }`. Three+ matches → must use `FitnessWheelPickerColumn`.

These structural patterns are the ones the agent tends to miss because no named component matches a keyword in the diff.

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

#### Component Extraction (DRY vs KISS Balance)

When reviewing code for reuse opportunities, apply these guidelines to avoid both under- and over-abstraction:

**Extract when ALL of these are true:**
1. **3+ copies** of the same structural pattern exist (2 copies may be coincidence)
2. The shared part is **purely structural/presentational** (chrome, layout, animation) — not business logic
3. The extraction **reduces** each call site (the component is simpler to use than the code it replaces)
4. The component has a **stable contract** — it won't need constant parameter additions as features diverge

**Keep as copy when ANY of these are true:**
1. Only 2 instances exist and they may diverge in the future
2. The "shared" code contains **business logic** that differs subtly between call sites
3. Extracting would require **more parameters than lines saved** (the abstraction leaks)
4. The component would need `if/switch` branches for each call site (shotgun surgery)

**SwiftUI-specific guidance:**
- Use **`@ViewBuilder` container views** for structural wrappers (sheet chrome, card containers, overlay patterns)
- Use **ViewModifiers** for behavior/styling additions (keyboard handling, animation, styling)
- Use **helper functions/types** for shared logic (weight formatting, date filtering, seat parsing)
- Never mix structural containers with business logic — the container provides the *frame*, the caller provides the *content*

**Rule of thumb:** If extracting a component means the call site reads like a sentence describing what the UI *is* rather than *how it's built*, the abstraction is at the right level.

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
- **Cached ViewModel sync (DEPRECATED pattern, kept for historical context):** In the legacy snapshot+polling architecture, cached VMs needed a dedicated sync method (e.g. `syncExercise(_:)`) to suppress re-entrant `onUpdate` callbacks. **Better: don't cache.** With SwiftData `@Model` as SoT (ADR-0001) and `@Query` / `@Bindable` driving the view (`FitnessPersistenceUI` ModelViews), there is no cached VM and no sync workaround is needed. If a review surfaces a new `syncExercise`-style method, treat it as a §13 snapshot-state smell: the cache is the bug.
- **Equatable traps:** If a model has id-only `Equatable`, guards like `exercise != oldValue` miss content changes. Verify sync guards compare meaningful fields, or rely on SwiftData `@Model` observation instead of DTO equality.
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

##### `@Injected` vs Constructor-DI — choosing the right flavour

Both are legitimate uses of the Factory DI container. The difference is **where the lookup happens** and what that means for tests, ownership, and Swift 6 concurrency.

| Flavour | Pattern | When to use |
|---------|---------|-------------|
| **Property** (`@Injected`) | `@Injected(\.x) private var x` — resolved from `Container.shared` at first access | Views, long-lived caches/singletons, coordinators that don't need unit-test mocking. Ownership is implicit via the global container. |
| **Constructor with Factory default** | `init(x: X? = nil) { self.x = x ?? Container.shared.x() }` | ViewModels, services, use cases, anything with unit tests. Tests pass mocks directly; production gets the Factory default. |

Decision criteria:

1. **Has the type got unit tests?** If yes → constructor-DI. Tests should not need `Container.shared.register { … }` + `.serialized` to isolate.
2. **Do you care who owns the dependency?** If yes → constructor-DI (the signature tells the story).
3. **Is the type `@MainActor` with a `nonisolated init`?** Property `@Injected` forces `MainActor.assumeIsolated` gymnastics in the Factory registration. Constructor-DI avoids this.
4. **Is the dependency short-lived or request-scoped?** Use constructor-DI; `@Injected` is for long-lived singletons.

Migration pattern (same shape used in `WorkoutsViewModel`):

```swift
// BEFORE — Property injection
public final class ExerciseManagementService: ExerciseManaging {
    @Injected(\.exerciseStorage) private var storageService
    @Injected(\.analyticsStorage) private var analyticsStorage
    @Injected(\.workoutStorage) private var workoutStorageService
    public init() {}
}

// AFTER — Constructor injection with Factory default
public final class ExerciseManagementService: ExerciseManaging {
    private let storageService: ExerciseStoring
    private let analyticsStorage: AnalyticsStoring
    private let workoutStorageService: WorkoutStoring

    public init(
        exerciseStorage: ExerciseStoring? = nil,
        analyticsStorage: AnalyticsStoring? = nil,
        workoutStorage: WorkoutStoring? = nil
    ) {
        self.storageService = exerciseStorage ?? Container.shared.exerciseStorage()
        self.analyticsStorage = analyticsStorage ?? Container.shared.analyticsStorage()
        self.workoutStorageService = workoutStorage ?? Container.shared.workoutStorage()
    }
}
```

The production call-site stays `ExerciseManagementService()` (Factory factory in `StorageContainer.swift` is unchanged). Tests now write `ExerciseManagementService(exerciseStorage: mockES, …)` with no global state touched.

##### Common misconception

"Property `@Injected` is a service-locator antipattern and should be removed project-wide." Wrong. `@Injected` IS dependency injection (via Factory), just in a weaker flavour. Views and caches are legitimate users. The goal is **not** to eliminate `@Injected` — it is to **use constructor-DI where unit-testability matters**, and to keep `@Injected` where it doesn't.

This is DI-**evolution**, not DI-**reversal**. The Factory container and protocol registrations remain. Only the access pattern changes, selectively.

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

#### 13h. Duplicate Domain-State Holders

A view that holds a `@State` ViewModel which mirrors a domain entity (with a stable identity / UUID) — while the **same identity** is also held elsewhere (another VM cache, another view's `@State`) — is a guaranteed sync bug. Two lifecycles for one identity = staleness.

Real example (Bug 1, historical — both `ExerciseCardViewModel` and the `cardViewModels` cache were deleted in T8d. The shape of the bug, however, is the lesson):

```swift
struct TrainingView: View {
    @State private var cardViewModel: ExerciseCardViewModel  // holds Exercise with id X

    init(exercise: Exercise, ...) {
        self._cardViewModel = State(wrappedValue: ExerciseCardViewModel(exercise: exercise) { ... })
        // exercise is "frozen" here. After finishExercise(), cardViewModel.exercise stays stale.
    }
}

// Simultaneously:
@Observable class MuscleCategorySelectionViewModel {
    private(set) var cardViewModels: [UUID: ExerciseCardViewModel]  // may also contain id X
}
```

A `syncExercise(...)`-style workaround is a symptom, not a fix. (The historic
`syncExercise` method was removed in T8d when the snapshot+polling architecture
itself was deleted. Mention this only if reviewing pre-T8d code.)

##### Search Pattern

```bash
# @State VMs introduced by the diff:
rg -n '@State\s+private\s+var\s+\w*ViewModel' FitnessApp Packages --glob '*.swift'

# UUID-keyed VM caches that already exist:
rg -n 'var\s+\w*ViewModels\s*:\s*\[UUID' Packages --glob '*.swift'
```

If both rg patterns hit in the same PR/diff → review trigger.

##### Accepted Patterns (Fix Options)

1. **Single source via `@Bindable`** on a SwiftData `@Model` — one identity, one lifecycle, observed by SwiftUI automatically:
   ```swift
   @Bindable var model: ExerciseModel
   ```
2. **Single source via `@Environment`** — the view reads through the existing cache instead of holding its own copy (illustrative; in this codebase the actual pattern is option 1 because `ExerciseCardViewModel` and its UUID-keyed cache are gone):
   ```swift
   @Environment(SomeSelectionViewModel.self) var selectionVM
   var card: SomeCardViewModel { selectionVM.cardViewModels[id]! }
   ```
3. **Pure rendering** — view takes `Exercise` as `let`; parent re-supplies on change:
   ```swift
   struct TrainingView: View {
       let exercise: Exercise   // re-rendered when parent updates
   }
   ```

##### Reviewer Acceptance Criterion

When a diff introduces `@State private var XViewModel` AND a VM cache for the same entity type already exists, the reviewer MUST require either:
- An ADR or commit-body comment that explains why two lifecycles are intentionally OK, OR
- One of the fix options above.

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

### 14. SwiftData Predicate Anti-Patterns (after `#Predicate` or `Query(filter:` in diff)

For every diff that introduces `#Predicate` or a `@Query(filter:)`, check the patterns below. Each is a known runtime-bug class on the iOS platform.

#### 14a. Optional-Chain in Predicate

```swift
// BAD — broken before iOS 17.5, fragile after
@Query(filter: #Predicate<ExerciseModel> { $0.workout?.id == workoutId })
```

Multi-hop chains (`?.a?.b`) crash at runtime with `unsupportedPredicate`.

**Fix** — denormalise the foreign key onto the child model:

```swift
@Model class ExerciseModel {
    @Attribute(.indexed) var workoutId: UUID   // denormalised
    var workout: WorkoutModel?
}

@Query(filter: #Predicate<ExerciseModel> { $0.workoutId == workoutId })
```

#### 14b. Force-Unwrap in Predicate

```swift
// BAD — crashes on nil
#Predicate { $0.workout!.id == workoutId }
```

**Fix** — same as 14a (denormalise).

#### 14c. `persistentModelID` Comparison Without Tests

```swift
@Query(filter: #Predicate { $0.persistentModelID == capturedID })
```

Works in practice today but is **not clearly documented** in Apple's SwiftData refs — risky across OS updates.

**Recommendation** — when the `@Model` already has `@Attribute(.unique) var id: UUID` (as `ExerciseModel` does), prefer `id == X`. Validated in this codebase via `ExerciseStorageService`.

#### 14d. `@Query` Without View-Identity Under Dynamic Filter

```swift
struct CategoryTileView: View {
    let workoutId: UUID                                   // changes when workout switches
    @Query private var exercises: [ExerciseModel]
    init(workoutId: UUID) {
        self.workoutId = workoutId
        _exercises = Query(filter: #Predicate { $0.workoutId == workoutId })
        // Predicate is captured at init — stays stale on parent re-render with same struct identity.
    }
}

// Parent — no .id() ⇒ same view identity ⇒ stale query
ForEach(categories) { CategoryTileView(workoutId: currentWorkoutId) }
```

**Fix** — force a fresh view identity when the filter input changes:

```swift
ForEach(categories) {
    CategoryTileView(workoutId: currentWorkoutId)
        .id(currentWorkoutId)      // new identity on switch ⇒ fresh @Query
}
```

#### 14e. `@ModelActor` Mutation While `@Query` Renders on `MainActor`

```swift
@ModelActor actor BackgroundUpdater {
    func updateAll() async {
        // mutates ExerciseModel instances
        try? modelContext.save()
    }
}
```

A `@Query` on the MainActor view does **not reliably** see updates from a background `ModelContext` (Stack Overflow, Jan 2026; Apple Forums Apr 2025).

**Fix**:
- Default: keep everything on `@MainActor`, single `ModelContext` (see ADR-001).
- If background mutation is required: emit an explicit refresh signal back to the MainActor context after `save()`.

#### Search Patterns for Reviewer

```bash
# 14a + 14b (optional / force chain in #Predicate):
rg -n '#Predicate' --glob '*.swift' -A2 | rg '\?\.|\!\.'

# 14c (persistentModelID in predicate):
rg -n 'persistentModelID\s*==' --glob '*.swift'

# 14d (dynamic-filter @Query — manual verification needed in parent ForEach):
rg -n '@Query' --glob '*.swift' -A5 | rg 'filter:.*captured|let.*=.*self\.'

# 14e (any @ModelActor mutator):
rg -n '@ModelActor' --glob '*.swift'
```

#### Acceptance Criterion

A diff that introduces `#Predicate` MUST:
- contain no `?.` or `!.` chains, OR comment explicitly why the chain is safe and tested
- if filter input is dynamic: parent must enforce view identity via `.id()`
- on `@ModelActor` mutation: an ADR must justify the MainActor bypass and describe the refresh signal back to UI

## Output: Orchestrated Subagent Review

After the main agent completes code changes, this skill **orchestrates** independent subagents for review and testing. The review checklist above serves as reference for the reviewer subagent and for manual reviews.

### Parallel Execution Pattern

Determine which subagents to spawn based on what changed:

```
# Swift files changed + .cursor/ files changed:
Parallel: [ROLE:reviewer] + [ROLE:tester] + [ROLE:verifier]

# Only Swift files changed:
Parallel: [ROLE:reviewer] + [ROLE:tester]

# Only .cursor/ files changed:
Single: [ROLE:verifier]  (handled by reviewing-agent-infrastructure skill)
```

### Step 1: Spawn Subagents in Parallel

Spawn reviewer and tester **in the same message** (parallel Task calls). Each subagent runs independently with fresh context. The `subagentStop` hook validates each one via role-specific gates.

**Reviewer subagent:**

```
Task(
  subagent_type: "generalPurpose",
  model: "fast",
  description: "Review Swift code changes",
  prompt: """
[ROLE:reviewer]

Read .cursor/agent-roles/reviewer.md for your full role definition and review checklist.

CHANGED FILES:
<paste list of changed Swift files>

GIT DIFF:
<paste the git diff of changed files>

For architecture context, read .cursor/references/architecture-documentation.md.

Return the full findings report.
"""
)
```

**Tester subagent:**

```
Task(
  subagent_type: "generalPurpose",
  model: "fast",
  description: "Run affected package tests",
  prompt: """
[ROLE:tester]

Read .cursor/agent-roles/tester.md for your full role definition and test commands.

CHANGED FILES:
<paste list of changed Swift files>

Determine affected packages and run their tests via xcodebuild.
Return a summary of test results.
"""
)
```

### Step 2: Handle Results

After both subagents return:

1. **Reviewer result:** If Bug-severity findings exist, fix them immediately. Nit-severity findings can be noted.
2. **Tester result:** If tests failed, fix the failures and re-run.
3. If both pass, the task is complete — stamps were written by the subagents.

### Fallback: Direct Review

When the user explicitly asks to "review" or "check" code (not post-change validation), you may perform the review directly using the checklist above instead of spawning subagents. In this case, write a **minimal** stamp to `.cursor/hooks/state/code-changes.stamp.md`:

```
date: 2026-04-11T14:30:00
result: PASS
files_inspected: 5
findings: 3
```

When triggered by a user review request, the stamp is optional.

### Mandatory Stamp Section: Residual Duplications

**Every** `code-changes.stamp.md` must include a `## Residual Duplications` section even when `§2 Reuse — PASS`. Reporting "PASS" without acknowledging duplications the agent *knowingly left in place* (e.g. out-of-scope call sites of a newly extracted component, shared pattern not yet consolidated) is a failure mode observed in prior audits (ref: enforcement-audit Apr 2026, body-metrics wheel refactor).

Required format:

```markdown
## Residual Duplications

- `WeightDecimalToggle` pattern duplicated in 5 call sites (ExercisePickerView:189, ExerciseWeightPickerView:76, ActiveSetEditPickerView:71, AddAnalyticsEntryView:269, ProfileView:530) — left in place; follow-up task to extract to FitnessUI.
- Inline weight-options generation in ProfileView.BodyMetricsWheelRow — `WeightOptionsGenerator` covers the String variant, typed `[Double]` variant not yet added.
```

If the agent genuinely found no leftover duplications, state `None.` explicitly — empty/missing section = stamp is incomplete.

**Why this matters.** A `Reuse — PASS` line without residuals tempts the next reviewer to assume the area is clean. Explicit residuals turn known-but-unfixed debt into a first-class artifact that future work can grep.

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
| New/deleted test file under `Packages/*/Tests/` | **Feature Map** tree — update test inventory |

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
