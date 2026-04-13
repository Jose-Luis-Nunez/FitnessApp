---
name: writing-ui-tests
description: >-
  Create new XCUITest UI tests for the FitnessApp project. Use when the user
  asks to create, write, or add a new UI test, test a new feature, add test
  coverage for a screen, or add accessibility identifiers for testing.
---

# Writing New UI Tests

For shared conventions (DSL, constraints, template, naming) see [ui-test-conventions.md](../../references/ui-test-conventions.md).

## Workflow

### Step 1 — Identify the User Flow

Read the **Navigation** and **Feature Map** sections in `.cursor/references/architecture-documentation.md` to understand the route between screens. Map each step to a `NavigationDestination` case.

Break the feature into a sequence of user-visible actions:

1. Which screen does the flow start on?
2. What does the user tap/fill/swipe at each step?
3. What is the expected end state (what should be visible/hidden)?

### Step 2 — Scan and Prepare Production Code

Scan the production Views for the identified flow and ensure all interactive elements are testable.

#### 2a. Find the View Files

Use the Feature Map and Navigation from Step 1 to locate the relevant View files. Check both `FitnessApp/Features/` and package sources — some screens delegate their UI to shared components (e.g. `TrainingSessionComponent`).

#### 2b. Scan for Interactive Elements

In each View, find elements the user interacts with:
- `Button` actions
- `onTapGesture` handlers
- `NavigationLink` destinations
- `TextField` / `SecureTextField` inputs
- Any element with `.onTapGesture` or `.contentShape(Rectangle())`

#### 2c. Check Coverage

For each interactive element:
1. **Accessibility Identifier** — does it have `.accessibilityIdentifier(AID.x)`? If not, add `enum AID` (or extend existing one) in the View with the new ID.
2. **Test ID constant** — does `Config/TestAccessibilityIDs.swift` have a matching constant? If not, add it.
3. **DSL function** — does `ElementActions.swift` have a function for this interaction type? If not, add it.
4. **Fixture** — does `Fixtures/TestFixtures.swift` have a preset for this screen's data? If not, add one.

### Step 3 — Write the Test

Use the test template from [ui-test-conventions.md](../../references/ui-test-conventions.md). Key rules:

- Inherit from `BaseTest`
- Mark test methods `@MainActor`
- First line: `launch(training:)` with explicit test data, or `launch(category:)` for screens without exercise data, or `launchHome()` for full journeys
- Only DSL functions and test ID constants (e.g. `TrainingIDs.doneButton`) — no raw API, no hardcoded strings
- Always pass mock data explicitly via `TestExerciseFixture` — no implicit defaults
- Use `tapOnIfExists` for conditional elements

### Step 4 — Review the Result

Review the finished test file against the **Review Checklist** in [ui-test-conventions.md](../../references/ui-test-conventions.md). Fix any violations before considering the test done.

## Documentation Sync

When you edit files under `FitnessAppUITests/`, check if the change affects `references/ui-test-conventions.md` and update it in the **same task**:

| What changed | What to update in `ui-test-conventions.md` |
|---|---|
| DSL function added/renamed/removed in `ElementActions.swift` | **DSL Function Reference** table |
| `TestDefaults` constant added/changed | **Timeout Defaults** table |
| Selector enum added/renamed/removed | **Project Structure** tree + examples if affected |
| Selector constant added/renamed/removed | Check examples and **Reference Example** for stale references |
| `BaseTest` API changed | **Test Template** and rules |
| New file/folder under `FitnessAppUITests/` | **Project Structure** tree |
| Deleted file under `FitnessAppUITests/` | **Project Structure** tree — remove entry |

Also update the **Review Checklist** in `ui-test-conventions.md` if the change affects validation rules.
