# UI Test Reference

Shared conventions for writing and updating UI tests.

## Project Structure

```
FitnessAppUITests/
├── Base/BaseTest.swift              # XCTestCase subclass, all tests inherit from this
├── Config/
│   ├── UITestScreen.swift           # Screen enum for launch config
│   ├── UITestLaunchConfig.swift     # Codable config sent to app via launchEnvironment
│   └── AccessibilityIDs.swift       # ID constants mirroring view-local AIDs
├── DSL/
│   └── ElementActions.swift         # Free functions: tapOn, verifyExists, fill, etc.
├── Fixtures/
│   ├── TestFixtures.swift           # UITestLaunchConfig factory + TestExerciseFixture
│   └── ExerciseFixtures.swift       # Named exercise presets (.defaultArmsExercise)
└── Tests/*Tests.swift               # Test files
```

The app target contains `Core/Testing/UITestRouter.swift` (compiled only under `UITESTING` flag) which reads the launch config and routes the `AppRouter` to the target screen.

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

The test target maintains its own copy of the ID strings in `Config/TestAccessibilityIDs.swift`. These must be kept in sync with the view-local `enum AID`. If they drift, the test fails immediately -- which is the desired behavior.

### Current Test ID Enums

| Test Enum | Source View | IDs |
|-----------|-------------|-----|
| `TrainingIDs` | `FloatingActionButtonsView.AID`, `SimpleActiveSetView.AID` | `doneButton`, `finishButton`, `startButton`, `allDoneButton`, `quickDoneButton`, `controlButton(_:)`, `repsField(set:)`, `quickDoneSetButton(index:)` |
| `HomeIDs` | `MuscleCategorySelectionView.AID` | `categoryTile(for:)` |
| `MuscleCategoryIDs` | `IdleActiveCardView.AID` | `startExercise` |
| `ExerciseIDs` | `InactiveCardView.AID` | `nameLabel` |
| `ExerciseCardIDs` | `ExerciseCardContainerView` | `completedCard(_:)`, `activeCard(_:)`, `idleCard(_:)`, `completedCardPrefix`, `activeCardPrefix`, `idleCardPrefix` |

## Test Fixtures

Mock data is defined in `Fixtures/ExerciseFixtures.swift` as `TestExerciseFixture` structs. Tests pass fixtures explicitly via `launch(training:)` -- the app requires all fields (no defaults).

```swift
try launch(training: .defaultArmsExercise)
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
| Assert element is gone | `verifyNotExists(_:)` |
| Assert element exists by ID prefix | `verifyExistsWithPrefix(_:)` |
| Assert no element with ID prefix | `verifyNotExistsWithPrefix(_:)` |
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
- First line: `launch(training:)`, `launch(category:)`, `launchSchedule()`, or `launchHome()`
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

When a production View's `AID` constant is renamed or deleted, update `Config/TestAccessibilityIDs.swift` to match. Stale constants that reference non-existent IDs cause test failures.

## Naming Patterns

- View-local identifiers: `id_<context>_<element>` (e.g. `id_button_done`, `id_category_tile_arms`)
- View-local enum: `enum AID` inside each View struct
- Test ID enums: `<Screen>IDs` (e.g. `TrainingIDs`, `HomeIDs`) in `Config/TestAccessibilityIDs.swift`
- Dynamic IDs: static functions returning `String` (e.g. `repsField(set:)`)

## Decision Flowchart

```
Need to interact with an element in a test
  |
  +-- Has enum AID with accessibilityIdentifier in the View?
  |   +-- YES -> Add matching constant to Config/TestAccessibilityIDs.swift -> use DSL function
  |   +-- NO  -> Add enum AID to View + .accessibilityIdentifier(AID.x)
  |              -> Add matching constant to Config/TestAccessibilityIDs.swift -> use DSL function
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

Supported screens: `.training` (requires `TestExerciseFixture`), `.category`, `.schedule`.

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
- First line: `launch(training:)`, `launch(category:)`, `launchSchedule()`, or `launchHome()`
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
