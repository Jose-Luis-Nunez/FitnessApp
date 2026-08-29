---
name: writing-ui-tests
description: >-
  Create new XCUITest UI tests for the FitnessApp project. Use when the user
  asks to create, write, or add a new UI test, test a new feature, add test
  coverage for a screen, or add accessibility identifiers for testing.
---

# Writing New UI Tests

For shared conventions see the routing table in `.claude/references/ui-test-conventions.md`.

## Workflow

### Step 0 — Pass the Test Selection Gate

Read `.claude/references/test-selection-policy.md` and evaluate impact,
likelihood, detection advantage, and maintenance cost before creating a UI
test. A UI test is justified only for a critical user journey or platform
integration that cannot be proven reliably at a lower layer.

Run `bash .claude/hooks/lib/test-domain-risk.sh classify worktree` and apply the
domain baseline. Training/Exercise is blocker; Workouts and Analytics are high;
Profile and Feedback are low. Technical risk may raise, never lower, that tier.

If the gate does not pass, do not create the UI test. Prefer a focused unit or
integration test when one has better detection value, or explicitly report that
no new test is justified for a low-impact, low-likelihood scenario.

### Step 1 — Identify the User Flow

Read the **Navigation** and **Feature Map** sections in `.claude/references/architecture-documentation.md` to understand the route between screens. Map each step to a `NavigationDestination` case.

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
2. **Test ID constant** — does `Selectors/AccessibilityIDs.swift` have a matching constant? If not, add it.
3. **DSL function** — does `ElementActions.swift` have a function for this interaction type? If not, add it.
4. **Fixture** — does `Fixtures/TestFixtures.swift` have a preset for this screen's data? If not, add one.

If a newly added selector is not found on the first test run, follow
`debugging-ui-tests` or the decision tree in
`.claude/references/ui-test-conventions.md` before changing the AID, production
view, or timeout.

### Step 3 — Write the Test

Use the test template from `.claude/references/ui-test/authoring.md`. Key rules:

- Inherit from `BaseTest`
- Mark test methods `@MainActor`
- First line: `launch(exerciseCategory:)` or `launch(exerciseList:)` with explicit test data, followed by the normal Start interaction when the flow needs the training sheet; use `launch(category:)` only for category screens without exercise data, or `launchHome()` for full journeys
- Only DSL functions and test ID constants (e.g. `TrainingIDs.doneButton`) — no raw API, no hardcoded strings
- Always pass mock data explicitly via `TestExerciseFixture` — no implicit defaults
- Use `tapOnIfExists` for conditional elements

### Step 4 — Review the Result

Review the finished test file against the checklist in `.claude/references/ui-test/review-checklist.md`. Confirm that the test still passes the Selection Gate after its real fixture and flow cost are known, then fix any remaining violations before considering the test done.

## Documentation Sync

When you edit files under `FitnessAppUITests/`, check if the change affects `references/ui-test-conventions.md` and update it in the **same task**:

| What changed | What to update under `.claude/references/ui-test/` |
|---|---|
| DSL function added/renamed/removed in `ElementActions.swift` | **DSL Function Reference** table |
| `TestDefaults` constant added/changed | **Timeout Defaults** table |
| Selector enum added/renamed/removed | **Project Structure** tree + examples if affected |
| Selector constant added/renamed/removed | Check examples and **Reference Example** for stale references |
| `BaseTest` API changed | **Test Template** and rules |
| New file/folder under `FitnessAppUITests/` | **Project Structure** tree |
| Deleted file under `FitnessAppUITests/` | **Project Structure** tree — remove entry |
| Selector-diagnosis tooling/steps changed | `ui-test/diagnosing.md` |

Also update the checklist in `ui-test/review-checklist.md` if the change affects validation rules.
