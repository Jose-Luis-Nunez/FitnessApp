---
name: updating-ui-tests
description: >-
  Update, refactor, or modernize existing XCUITest UI tests in the FitnessApp
  project. Use when the user asks to update, refactor, modernize, or clean up
  an existing UI test, or when a test is outdated or uses wrong patterns. For
  tests that fail or have selectors that cannot be found, use
  `debugging-ui-tests` instead.
---

# Updating Existing UI Tests

For shared conventions see the routing table in `.claude/references/ui-test-conventions.md`.

## Workflow

### Step 0 — Re-evaluate Test Value

Read `.claude/references/test-selection-policy.md` and apply its Selection Gate
before repairing or re-recording an affected test. Retain the test only when its
expected risk reduction still exceeds its runtime, flakiness, fixture, and
baseline-maintenance cost.

Run `bash .claude/hooks/lib/test-domain-risk.sh classify worktree` and use its
domain baseline for the retention decision. Mixed changes use the highest tier;
technical risk may raise but never lower it.

If a low-value legacy test does not pass the gate, remove the test and any
fixtures, baselines, or dependencies used only by it. Do not update a test only
to keep the suite green.

### Step 1 — Review Test and Check Production Code

Perform two analyses on the existing test:

1. **Convention review** — check the test against the checklist in `.claude/references/ui-test/review-checklist.md` (raw API usage, hardcoded strings, structure issues, selector mismatches)
2. **Production scan** — read the test, extract all test ID references, find the production Views containing those identifiers. Check whether identifiers still exist in production `enum AID` constants, find new untested interactive elements, and flag stale selectors

If the test fails on the first run, follow `debugging-ui-tests`. The diagnosis
order in `.claude/references/ui-test-conventions.md` (use-case flow + selector
sequence → selector present in tree? → identifier match → set + layer check →
timing) is mandatory before applying any fix from Step 2.

Apply all fixes in Step 2.

### Step 2 — Fix and Extend

Based on both agent reports, apply fixes:

1. **Replace raw API** with DSL functions (`tapOn`, `verifyExists`, etc.)
2. **Replace hardcoded strings** with test ID constants (e.g. `TrainingIDs.doneButton`)
3. **Fix structure** (inherit `BaseTest`, add `@MainActor`, add launch sequence)
4. **Add missing identifiers** — add `enum AID` entry in the production View, then add `.accessibilityIdentifier(AID.x)` to the element
5. **Add matching test IDs** — add the new constant to the appropriate enum in `Selectors/AccessibilityIDs.swift`
6. **Remove stale test IDs** that reference deleted `AID` constants
7. **Make mock data explicit** — replace implicit defaults with `TestExerciseFixture` passed via `launch(exerciseCategory:)` or `launch(exerciseList:)`; training tests then open the sheet through the normal Start interaction
8. **Add new test steps** for elements that were added to the screen since the test was written

### Step 3 — Review the Result

Review the updated test file against the checklist in `.claude/references/ui-test/review-checklist.md`. Reconfirm the retention decision with the actual maintenance cost exposed by the update, then fix any remaining violations before considering the update done.

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
