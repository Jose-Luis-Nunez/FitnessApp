---
name: writing-ui-tests
description: >-
  Create new XCUITest UI tests for the FitnessApp project. Use when the user
  asks to create, write, or add a new UI test, test a new feature, add test
  coverage for a screen, or add accessibility identifiers for testing.
---

# Writing New UI Tests

For shared conventions (DSL, constraints, template, naming) see [ui-test-conventions/reference.md](../ui-test-conventions/reference.md).

## Workflow

### Step 1 — Identify the User Flow

Read the **Navigation** and **Feature Map** sections in `.cursor/references/architecture.md` to understand the route between screens. Map each step to a `NavigationDestination` case.

Break the feature into a sequence of user-visible actions:

1. Which screen does the flow start on?
2. What does the user tap/fill/swipe at each step?
3. What is the expected end state (what should be visible/hidden)?

### Step 2 — Run the Prep Agent

Launch `uitest-prep-agent` with the screen name or flow description. It scans the production Views and reports which elements have identifiers, selectors, and DSL coverage — and which don't.

The prep agent is read-only. **You** fix all findings it reports before writing the test:

- **Missing identifier** → add `.accessibilityIdentifier("id_<context>_<element>")` in the production View
- **Missing selector** → add `static let` to the appropriate `Selectors/` enum
- **Missing DSL function** → add to `ElementActions.swift`

### Step 3 — Write the Test

Use the test template from [ui-test-conventions/reference.md](../ui-test-conventions/reference.md). Key rules:

- Inherit from `BaseTest`
- Mark test methods `@MainActor`
- First line: `app.launch()`
- Only DSL functions and Selector constants — no raw API, no hardcoded strings
- Use `tapOnIfExists` for conditional elements

### Step 4 — Review the Result

Launch `uitest-reviewer-agent` on the finished test file. Fix any reported violations before considering the test done.
