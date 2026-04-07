# UI Test Reference

Shared conventions for writing and updating UI tests.

## Project Structure

```
FitnessAppUITests/
├── Base/BaseTest.swift          # XCTestCase subclass, all tests inherit from this
├── DSL/
│   └── ElementActions.swift     # Free functions: tapOn, verifyExists, fill, etc.
├── Selectors/
│   ├── HomeSelectors.swift
│   ├── MuscleCategorySelectors.swift
│   └── TrainingSelectors.swift
└── *Tests.swift                 # Test files
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
        app.launch()

        tapOn(FeatureSelectors.actionButton)
        fill(FeatureSelectors.inputField, with: "value")

        verifyExists(FeatureSelectors.successIndicator)
        verifyNotExists(FeatureSelectors.actionButton)
    }
}
```

Rules:
- Inherit from `BaseTest` (provides `app`, `setUp`, `tearDown`)
- Mark test methods `@MainActor`
- First line always: `app.launch()`
- One test method per user scenario; name it `test<WhatTheUserDoes>`
- Only DSL functions and Selector constants — no raw XCUITest API, no hardcoded strings

### Conditional UI

Use `tapOnIfExists` for elements that may or may not appear:

```swift
tapOnIfExists(TrainingSelectors.startButton)
```

For loops over repeated actions, wait for UI feedback before continuing:

```swift
for setIndex in 1...3 {
    tapOn(TrainingSelectors.doneButton)
    waitForNonEmptyLabel(TrainingSelectors.repsField(set: setIndex - 1))
}
```

## Constraints

### Always Use DSL — Never Raw XCUITest API in Tests

```swift
// BAD
let tile = app.descendants(matching: .any)
    .matching(identifier: "id_category_tile_arms")
    .firstMatch
tile.tap()

// GOOD
tapOn(HomeSelectors.categoryTile)
```

### Selectors — Never Hardcode Strings in Tests

```swift
// BAD
tapOn("id_button_start")

// GOOD
tapOn(TrainingSelectors.doneButton)
```

### Element Identification Priority

1. **`accessibilityIdentifier`** — most reliable, language-independent
2. **`label:`** — only for system controls without identifier
3. **`NSPredicate`** — avoid; only if pattern matching is truly required

Never resort to predicates or labels when an identifier can be added to the production code.

## Naming Patterns

- Identifiers: `id_<context>_<element>` (e.g. `id_button_done`, `id_category_tile_arms`)
- Selector enums: `<ScreenName>Selectors` (e.g. `HomeSelectors`, `TrainingSelectors`)
- Dynamic selectors: static functions returning `String` (e.g. `repsField(set:)`)

## Decision Flowchart

```
Need to interact with an element in a test
  │
  ├─ Has accessibilityIdentifier in production code?
  │   ├─ YES → Add static let to Selectors enum → use DSL function
  │   └─ NO  → Add .accessibilityIdentifier("id_...") in View first
  │            → Add static let to Selectors enum → use DSL function
  │
  └─ DSL function exists for this interaction?
      ├─ YES → Use it
      └─ NO  → Add new function to ElementActions.swift → then use it
```

## Reference Example

```swift
import XCTest

final class TrainingUITests: BaseTest {

    @MainActor
    func testFullTrainingFlow() throws {
        app.launch()

        tapOn(HomeSelectors.categoryTile)
        tapOn(MuscleCategorySelectors.startExercise, timeout: TestDefaults.longTimeout)

        for setIndex in 1...3 {
            tapOn(TrainingSelectors.doneButton)
            waitForNonEmptyLabel(TrainingSelectors.repsField(set: setIndex - 1))
        }

        tapOn(TrainingSelectors.finishButton)
        verifyNotExists(TrainingSelectors.finishButton)
    }
}
```
