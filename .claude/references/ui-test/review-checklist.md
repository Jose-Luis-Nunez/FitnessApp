# UI Test Review Checklist


After writing or updating a UI test, verify the result against these rules. Flag violations per category.

### 0. Risk-Based Selection

Confirm the test passes `.claude/references/test-selection-policy.md`:

- It protects a named critical user journey or platform integration.
- A unit or integration test cannot provide equivalent detection value.
- Its regression impact and likelihood justify runtime, fixture, and flake cost.
- An affected legacy test that fails this gate is removed, not mechanically repaired.

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
- First line: `launch(exerciseList:)`, `launch(exerciseCategory:)`, `launch(category:)`, `launchCategorySelection()`, `launchSchedule()`, `launchProfile()`, or `launchHome()`
- No business logic or complex setup in the test -- just DSL calls

### 4. Selector Completeness

For each test ID constant referenced in test files, verify:
- The corresponding `accessibilityIdentifier` exists in a production View's `enum AID`
- The test ID constant value matches the production identifier exactly

### How to Review

1. Read the changed or new test file
2. Apply rules 1--3 above
3. Read the test ID enums used and cross-reference with production View `enum AID` constants (rule 4)
