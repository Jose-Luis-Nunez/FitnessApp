# UI Test Reference

Shared conventions for writing and updating UI tests.

## Project Structure

```
FitnessAppUITests/
├── Base/BaseTest.swift              # XCTestCase subclass, all tests inherit from this
├── Config/
│   ├── UITestScreen.swift           # Screen enum for launch config
│   └── UITestLaunchConfig.swift     # Codable config sent to app via launchEnvironment
├── Selectors/
│   └── AccessibilityIDs.swift       # ID constants mirroring production AIDs
├── DSL/
│   └── ElementActions.swift         # Free functions: tapOn, verifyExists, fill, etc.
├── Fixtures/
│   ├── TestFixtures.swift           # UITestLaunchConfig factory + TestExerciseFixture
│   └── ExerciseFixtures.swift       # Named exercise presets (.defaultArmsExercise)
└── Tests/
    ├── WorkoutTileVisualTests.swift # Category/workout screenshots + geometry parity
    ├── TrainingNavigationUITests.swift # List/category training return paths
    └── *Tests.swift                 # Other test files
```

The app target contains `Shared/Navigation/UITestLaunchStrategy.swift` (compiled only under the `UITESTING` flag, which is set on the `UITesting` build configuration). It implements `AppLaunchStrategy`, reads `UITEST_CONFIG` from `launchEnvironment`, seeds a `WorkoutModel` + `ExerciseModel` pair into the SwiftData container (post-T8d, `TrainingView` resolves the navigated id via `@Query`, so the fixture must exist on disk before navigation), and returns the initial `[NavigationDestination]` stack to the app's `NavigationStack`.

> Build-config note: UI tests must be run via the `FitnessApp UITests` scheme (not `FitnessApp`). Only that scheme builds with the `UITesting` configuration that defines `UITESTING`. See `.claude/rules/build-and-test.mdc` § "UI Tests".

## Accessibility ID Pattern

Each SwiftUI View that needs accessibility identifiers defines an `enum AID` at the top of its struct body. This is the **source of truth** for all IDs in that view.

```swift
struct MyView: View {
    enum AID {
        static let submitButton = "id_button_submit"
        static func row(at index: Int) -> String { "id_row_\(index)" }
    }

    var body: some View {
        Button("Submit") { ... }
            .accessibilityIdentifier(AID.submitButton)
    }
}
```

The test target maintains its own copy of the ID strings in `Selectors/AccessibilityIDs.swift`. These must be kept in sync with production identifiers. If they drift, the test fails immediately -- which is the desired behavior.

### Current Test ID Enums

The single source of truth for the constants below is `Packages/FitnessCore/Sources/FitnessCore/AccessibilityIDs.swift` (hoisted into `FitnessCore` at T7-0 so the model-driven views in `FitnessPersistenceUI` can reference them without a dependency cycle). The "Applied in" column lists the views that attach the identifier via `.accessibilityIdentifier(...)`. The test target keeps a parallel copy in `FitnessAppUITests/Selectors/AccessibilityIDs.swift` (string-equal — drift = test failure, by design).

| Test Enum | Defined in | Applied in | IDs |
|-----------|-----------|------------|-----|
| `TrainingIDs` | `FitnessCore.AccessibilityIDs` | `BottomActionBarView`, `SimpleActiveSetView`, `CompactTimerComponent` | `cancelTraining`, `doneButton`, `finishButton`, `startButton`, `allDoneButton`, `quickDoneButton`, `controlButton(_:)`, `repsField(set:)`, `quickDoneSetButton(index:)` |
| `HomeIDs` | `FitnessCore.AccessibilityIDs` | `MuscleCategorySelectionView` (category tiles via `CategoryTileModelView`; list-mode toggle) | `categoryTile(for:)`, `listViewToggle`; list toggle label: `Exercise list` |
| `MuscleCategoryIDs` | `FitnessCore.AccessibilityIDs` | `MuscleCategoryView`, `IdleActiveCardModelView` (post-T8d; previously `IdleActiveCardView`) | `screen`, `startExercise`; start button label: `Start exercise` |
| `ExerciseIDs` | `FitnessCore.AccessibilityIDs` | `InactiveCardModelView` (post-T8d; previously `InactiveCardView`) | `nameLabel` |
| `ExerciseCardIDs` | `FitnessCore.AccessibilityIDs` | `ExerciseCardModelView` (post-T8d; previously `ExerciseCardContainerView`) | `completedCard(_:)`, `activeCard(_:)`, `idleCard(_:)`, `completedCardPrefix`, `activeCardPrefix`, `idleCardPrefix` |
| `WorkoutIDs` | `FitnessCore.AccessibilityIDs` | `WorkoutTileView`, `CreateWorkoutView` | `tilePrefix`, `settingsPrefix`, `tile(_:)`, `settings(_:)`, `createTitle`, `createNameField`, `createTypePicker`, `createSaveButton` |
| `BottomBarIDs` | `FitnessCore.AccessibilityIDs` | `BottomMenuBarView` | `contextMenu`, `workoutsTab`, `trainingTab`, `analyticsTab`, `scheduleTab`, `profileTab` |

## Test Fixtures

Mock data is defined in `Fixtures/ExerciseFixtures.swift` as `TestExerciseFixture` structs. Tests pass fixtures explicitly via `launch(training:)` -- the app requires all fields (no defaults).

```swift
try launch(training: .defaultArmsExercise)
try launch(exerciseList: .defaultArmsExercise)
try launch(exerciseCategory: .defaultArmsExercise)
```

Named presets (e.g. `.defaultArmsExercise`) keep tests readable. For custom scenarios, create a fixture inline:

```swift
let heavy = TestExerciseFixture(name: "Deadlift", weight: 120.0, reps: 5, sets: 5, noSeats: true, icon: "dumbbell", category: "back")
try launch(training: heavy)
```

## DSL Function Reference

| Action | DSL Function |
|--------|-------------|
| Tap an element | `tapOn(_:)` or `tapOn(label:)` |
| Tap if it might not appear | `tapOnIfExists(_:)` |
| Type into a text field | `fill(_:with:)` |
| Type into a picker input button | `fillPickerInput(_:with:)` |
| Assert element is visible | `verifyExists(_:)` |
| Assert enabled state | `verifyIsEnabled(_:)` / `verifyIsDisabled(_:)` |
| Assert a system-controlled menu option is visible by label | `verifyExists(label:)` |
| Assert element is gone | `verifyNotExists(_:)` |
| Assert element exists by ID prefix | `verifyExistsWithPrefix(_:)` |
| Assert no element with ID prefix | `verifyNotExistsWithPrefix(_:)` |
| Read element frames | `frameOf(_:)` / `framesOfElements(withPrefix:limit:)` |
| Sort measured frames by visual reading order | `sortFramesInReadingOrder(_:)` |
| Attach a diagnostic full-screen screenshot | `attachDiagnosticScreenshot(named:)` |
| Assert element label content | `verifyLabel(_:equals:)` |
| Wait for label to be populated | `waitForNonEmptyLabel(_:)` |
| Scroll until element is visible | `swipeUpUntilVisible(_:)` |

If no function exists for the interaction, **add it to `ElementActions.swift`** following existing patterns (timeout, `findElement`, predicate-based waits).

## Timeout Defaults

All DSL functions use `TestDefaults` for consistent timeouts:

| Constant | Value | Usage |
|----------|-------|-------|
| `TestDefaults.timeout` | 5.0s | Standard wait for elements |
| `TestDefaults.shortTimeout` | 2.0s | Disappearance checks, optional elements |
| `TestDefaults.longTimeout` | 10.0s | Slow-loading screens |

Override per call site when needed: `tapOn(selector, timeout: TestDefaults.longTimeout)`.

## Test Template

```swift
import XCTest

final class <Feature>UITests: BaseTest {

    @MainActor
    func test<Scenario>() throws {
        try launch(training: .defaultArmsExercise)

        tapOn(TrainingIDs.doneButton)
        verifyExists(TrainingIDs.repsField(set: 0))
        verifyNotExists(TrainingIDs.finishButton)
    }
}
```

Rules:
- Inherit from `BaseTest` (provides `app`, `setUp`, `tearDown`)
- Mark test methods `@MainActor`
- First line: `launch(training:)`, `launch(exerciseList:)`, `launch(exerciseCategory:)`, `launch(category:)`, `launchCategorySelection()`, `launchSchedule()`, or `launchHome()`
- One test method per user scenario; name it `test<WhatTheUserDoes>`
- Only DSL functions and test ID constants -- no raw XCUITest API, no hardcoded strings
- Always pass explicit fixture data -- no implicit defaults

### Conditional UI

Use `tapOnIfExists` for elements that may or may not appear:

```swift
tapOnIfExists(TrainingIDs.quickDoneButton)
```

For loops over repeated actions, wait for UI feedback before continuing:

```swift
for setIndex in 1...3 {
    tapOn(TrainingIDs.doneButton)
    waitForNonEmptyLabel(TrainingIDs.repsField(set: setIndex - 1))
}
```

## Constraints

### Always Use DSL -- Never Raw XCUITest API in Tests

```swift
// BAD
let tile = app.descendants(matching: .any)
    .matching(identifier: "id_category_tile_arms")
    .firstMatch
tile.tap()

// GOOD
tapOn(HomeIDs.categoryTile(for: "arms"))
```

### Test ID Constants -- Never Hardcode Strings in Tests

```swift
// BAD
tapOn("id_button_start")

// GOOD
tapOn(TrainingIDs.startButton)
```

### Element Identification Priority

1. **`accessibilityIdentifier`** -- most reliable, language-independent
2. **`label:`** -- only for system controls without identifier
3. **`NSPredicate`** -- avoid; only if pattern matching is truly required

Never resort to predicates or labels when an identifier can be added to the production code.

### Stale IDs -- Keep in Sync

When a production identifier is renamed or deleted, update `Selectors/AccessibilityIDs.swift` to match. Stale constants that reference non-existent IDs cause test failures.

## Diagnosing a Failing Selector

A selector failure does not automatically mean "the selector is wrong" — it means the runner could not find the expected selector at the moment of the assertion. **Why** is the diagnostic question. Swapping the selector or bumping the timeout before diagnosing the actual cause is the most common failure mode and often hides the real bug (missing render, wrong screen, AID on the wrong UI layer).

Work the steps in order. **Do not skip ahead.**

1. **Understand the use-case flow and the selector sequence first.** What screen does the test expect? Which selectors does it interact with, in which order? Without this anchor, every later step is guesswork.
2. **Are the expected selectors actually present at the failure point?** Inspect the UI hierarchy at the moment of failure — generically via Xcode's xcresult viewer ("App element" attachment), or with the concrete fallback `xcrun xcresulttool export attachments --path <Test-*.xcresult> --output-path /tmp/uitest-attach` (the largest `*.txt` is the AX-tree). Also valid pre-run: `print(app.debugDescription)` from a temporary breakpoint in the test runner.
3. **If a selector is present:** does its identifier match exactly what the test queries for? If drift → update either `FitnessAppUITests/Selectors/AccessibilityIDs.swift` or the production `enum AID` (depending on which side was renamed unintentionally — see `Stale IDs — Keep in Sync` above).
4. **If no selector is present:** add one — and verify it ends up on the **correct UI layer**. Common layer mistakes: AID on a `VStack` wrapper while the tappable child is the actual `Button`; `accessibilityElement(children: .ignore)` on a parent that shadows the child's identifier; AID on a hidden/conditional branch that the test path never enters.
5. **Only if a correct selector is present and on the right layer:** consider timing. Try `tapOn(selector, timeout: TestDefaults.longTimeout)`. If that turns the test green, the data path is async (e.g. `@Query` materialises late); document the cause and consider whether to push the wait into production code (explicit "ready" state) instead of leaving a 10-second blanket timeout.

### Common Pitfalls

- Do not jump to "the selector is wrong" without first understanding the use-case flow and selector sequence.
- Do not raise the timeout first. Timing is step 5, not step 1 — a longer timeout often hides a layer or render-timing bug.
- Flaky ≠ selector bug. Flakes are usually render-timing or layer mistakes (AID on wrong wrapper, conditional branch never entered).

## Naming Patterns

- View-local identifiers: `id_<context>_<element>` (e.g. `id_button_done`, `id_category_tile_arms`)
- View-local enum: `enum AID` inside each View struct
- Test ID enums: `<Screen>IDs` (e.g. `TrainingIDs`, `HomeIDs`) in `Selectors/AccessibilityIDs.swift`
- Dynamic IDs: static functions returning `String` (e.g. `repsField(set:)`)

## Decision Flowchart

```
Need to interact with an element in a test
  |
  +-- Has enum AID with accessibilityIdentifier in the View?
  |   +-- YES -> Add matching constant to Selectors/AccessibilityIDs.swift -> use DSL function
  |   +-- NO  -> Add enum AID to View + .accessibilityIdentifier(AID.x)
  |              -> Add matching constant to Selectors/AccessibilityIDs.swift -> use DSL function
  |
  +-- DSL function exists for this interaction?
      +-- YES -> Use it
      +-- NO  -> Add new function to ElementActions.swift -> then use it
```

## Direct Navigation

For tests that focus on a specific screen, use `BaseTest` launch helpers to skip intermediate screens:

```swift
// Training screen with explicit fixture
try launch(training: .defaultArmsExercise)

// Category screen
try launch(category: "arms")

// Category-selection overview (deterministic UI-test launch)
try launchCategorySelection()

// Schedule screen
try launchSchedule()

// Home / Workouts screen (default)
launchHome()
```

The app reads the `UITEST_CONFIG` environment variable and uses `AppRouter.replaceAll(with:)` to build the navigation stack programmatically so back-navigation still works. For training, **all exercise fields are required** -- the app will not navigate if any are missing.

**When to use which:**

| Scenario | Launch method |
|----------|--------------|
| Testing the full user journey (home to finish) | `launchHome()` + navigate via DSL |
| Testing behavior on a specific screen | `launch(training:)`, `launch(category:)`, or `launchSchedule()` |
| Comparing Category/Workout overview geometry | `launchCategorySelection()` then tap the Workouts tab |

Supported screens: `.home` (category-selection overview), `.training` (requires `TestExerciseFixture`), `.category`, `.schedule`.

## Review Checklist

After writing or updating a UI test, verify the result against these rules. Flag violations per category.

### 1. No Raw XCUITest API in Test Files

Flag any direct usage of XCUITest API in test files (not in DSL files):

| Pattern in Test File | Violation |
|---|---|
| `app.descendants(matching:)` | Use `tapOn` / `verifyExists` instead |
| `app.buttons[...]` | Use `tapOn` / `verifyExists` instead |
| `app.staticTexts[...]` | Use `verifyExists` instead |
| `.matching(identifier:)` | Use DSL function with test ID constant |
| `.matching(NSPredicate(...))` | Add identifier to View, use `tapOn` |
| `.firstMatch.tap()` | Use `tapOn` |
| `.waitForExistence(` | Use DSL verify/tap functions (they handle waits) |

### 2. No Hardcoded Strings

Flag any string literal used directly in DSL calls within test files:

```swift
// VIOLATION
tapOn("id_button_start")
verifyExists("id_some_element")

// CORRECT
tapOn(TrainingIDs.doneButton)
verifyExists(ExerciseIDs.nameLabel)
```

### 3. Test Structure

Check each test file for:
- Inherits from `BaseTest` (not `XCTestCase` directly)
- Test methods marked `@MainActor`
- First line: `launch(training:)`, `launch(category:)`, `launchCategorySelection()`, `launchSchedule()`, or `launchHome()`
- No business logic or complex setup in the test -- just DSL calls

### 4. Selector Completeness

For each test ID constant referenced in test files, verify:
- The corresponding `accessibilityIdentifier` exists in a production View's `enum AID`
- The test ID constant value matches the production identifier exactly

### How to Review

1. Read the changed or new test file
2. Apply rules 1--3 above
3. Read the test ID enums used and cross-reference with production View `enum AID` constants (rule 4)

## Reference Example

```swift
import XCTest

final class TrainingUITests: BaseTest {

    @MainActor
    func testFullTrainingFlow() throws {
        try launch(training: .defaultArmsExercise)

        for setIndex in 1...3 {
            tapOn(TrainingIDs.doneButton)
            waitForNonEmptyLabel(TrainingIDs.repsField(set: setIndex - 1))
        }

        tapOn(TrainingIDs.finishButton)
        verifyNotExists(TrainingIDs.finishButton)
    }
}
```
