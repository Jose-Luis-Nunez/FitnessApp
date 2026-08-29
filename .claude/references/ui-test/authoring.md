# Authoring a UI Test

Structure, template, naming, and a worked example.

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
    ├── WorkoutPickerUITests.swift   # Real wheel-row selection + overlay dismissal
    └── *Tests.swift                 # Other test files
```

The app target contains `Shared/Navigation/UITestLaunchStrategy.swift` (compiled only under the `UITESTING` flag, which is set on the `UITesting` build configuration). It implements `AppLaunchStrategy`, reads `UITEST_CONFIG` from `launchEnvironment`, seeds a `WorkoutModel` + `ExerciseModel` pair into the SwiftData container (`TrainingSheetView` resolves the presented id via `@Query`, so the fixture must exist on disk before the start tap), and returns the initial `[NavigationDestination]` stack to the app's `NavigationStack`.

> Build-config note: UI tests must be run via the `FitnessApp UITests` scheme (not `FitnessApp`). Only that scheme builds with the `UITesting` configuration that defines `UITESTING`. See `.claude/rules/build-and-test.mdc` § "UI Tests".

## Test Template

```swift
import XCTest

final class <Feature>UITests: BaseTest {

    @MainActor
    func test<Scenario>() throws {
        try launch(exerciseCategory: .defaultArmsExercise)
        tapOn(MuscleCategoryIDs.startExercise)

        tapOn(TrainingIDs.doneButton)
        verifyExists(TrainingIDs.repsField(set: 0))
        verifyNotExists(TrainingIDs.finishButton)
    }
}
```

Rules:
- Inherit from `BaseTest` (provides `app`, `setUp`, `tearDown`)
- Mark test methods `@MainActor`
- First line: `launch(exerciseList:)`, `launch(exerciseCategory:)`, `launch(category:)`, `launchCategorySelection()`, `launchSchedule()`, `launchProfile()`, or `launchHome()`
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

## Reference Example

```swift
import XCTest

final class TrainingUITests: BaseTest {

    @MainActor
    func testFullTrainingFlow() throws {
        try launch(exerciseCategory: .defaultArmsExercise)
        tapOn(MuscleCategoryIDs.startExercise)

        for setIndex in 1...3 {
            tapOn(TrainingIDs.doneButton)
            waitForNonEmptyLabel(TrainingIDs.repsField(set: setIndex - 1))
        }

        tapOn(TrainingIDs.finishButton)
        verifyNotExists(TrainingIDs.finishButton)
    }
}
```
