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

Read the **Navigation** and **Feature Map** sections in `.cursor/references/architecture.md` to understand the route between screens. Map each step to a `NavigationDestination` case.

Break the feature into a sequence of user-visible actions:

1. Which screen does the flow start on?
2. What does the user tap/fill/swipe at each step?
3. What is the expected end state (what should be visible/hidden)?

### Step 2 — Run the Prep Agent

Launch `ui-test-selector-creator` with the screen name or flow description. It scans the production Views and reports which elements have identifiers, selectors, and DSL coverage — and which don't.

The prep agent is read-only. **You** fix all findings it reports before writing the test:

- **Missing identifier** → add `enum AID` (or extend existing one) in the production View with the new ID, then add `.accessibilityIdentifier(AID.x)` to the element
- **Missing test ID** → add matching constant to the appropriate enum in `Config/TestAccessibilityIDs.swift`
- **Missing DSL function** → add to `ElementActions.swift`
- **Missing fixture** → add a named preset to `Fixtures/TestFixtures.swift` if this screen needs mock data

### Step 3 — Write the Test

Use the test template from [ui-test-conventions.md](../../references/ui-test-conventions.md). Key rules:

- Inherit from `BaseTest`
- Mark test methods `@MainActor`
- First line: `launch(training:)` with explicit test data, or `launch(category:)` for screens without exercise data, or `launchHome()` for full journeys
- Only DSL functions and test ID constants (e.g. `TrainingIDs.doneButton`) — no raw API, no hardcoded strings
- Always pass mock data explicitly via `TestExerciseFixture` — no implicit defaults
- Use `tapOnIfExists` for conditional elements

### Step 4 — Review the Result

Launch `ui-test-reviewer` on the finished test file. Fix any reported violations before considering the test done.

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

Also update `ui-test-reviewer.md` and `ui-test-selector-creator.md` if the change affects their validation rules or report format.
