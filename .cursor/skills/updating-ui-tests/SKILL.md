---
name: updating-ui-tests
description: >-
  Update, fix, or modernize existing XCUITest UI tests in the FitnessApp
  project. Use when the user asks to update, fix, refactor, modernize, or
  clean up an existing UI test, or when a test is broken, outdated, or uses
  wrong patterns.
---

# Updating Existing UI Tests

For shared conventions (DSL, constraints, template, naming) see [ui-test-conventions.md](../../references/ui-test-conventions.md).

## Workflow

### Step 1 — Review Test and Check Production Code (parallel)

Launch both agents in parallel:

- `ui-test-reviewer` on the existing test file — reports convention violations (raw API usage, hardcoded strings, structure issues, selector mismatches)
- `ui-test-selector-creator` with the existing test file as input — checks whether identifiers still exist in production, finds new untested elements, and flags stale selectors

Both agents are read-only. **You** apply all fixes in Step 2.

### Step 2 — Fix and Extend

Based on both agent reports, apply fixes:

1. **Replace raw API** with DSL functions (`tapOn`, `verifyExists`, etc.)
2. **Replace hardcoded strings** with test ID constants (e.g. `TrainingIDs.doneButton`)
3. **Fix structure** (inherit `BaseTest`, add `@MainActor`, add launch sequence)
4. **Add missing identifiers** — add `enum AID` entry in the production View, then add `.accessibilityIdentifier(AID.x)` to the element
5. **Add matching test IDs** — add the new constant to the appropriate enum in `Config/TestAccessibilityIDs.swift`
6. **Remove stale test IDs** that reference deleted `AID` constants
7. **Make mock data explicit** — replace implicit defaults with `TestExerciseFixture` passed via `launch(training:)`
8. **Add new test steps** for elements that were added to the screen since the test was written

### Step 3 — Review the Result

Launch `ui-test-reviewer` on the updated test file. Fix any remaining violations before considering the update done.

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
