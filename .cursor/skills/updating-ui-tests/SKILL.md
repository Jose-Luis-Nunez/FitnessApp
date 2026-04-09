---
name: updating-ui-tests
description: >-
  Update, fix, or modernize existing XCUITest UI tests in the FitnessApp
  project. Use when the user asks to update, fix, refactor, modernize, or
  clean up an existing UI test, or when a test is broken, outdated, or uses
  wrong patterns.
---

# Updating Existing UI Tests

For shared conventions (DSL, constraints, template, naming) see [ui-test-conventions/reference.md](../ui-test-conventions/reference.md).

## Workflow

### Step 1 — Review Test and Check Production Code (parallel)

Launch both agents in parallel:

- `uitest-reviewer-agent` on the existing test file — reports convention violations (raw API usage, hardcoded strings, structure issues, selector mismatches)
- `uitest-prep-agent` with the existing test file as input — checks whether identifiers still exist in production, finds new untested elements, and flags stale selectors

Both agents are read-only. **You** apply all fixes in Step 2.

### Step 2 — Fix and Extend

Based on both agent reports, apply fixes:

1. **Replace raw API** with DSL functions (`tapOn`, `verifyExists`, etc.)
2. **Replace hardcoded strings** with test ID constants (e.g. `TrainingIDs.doneButton`)
3. **Fix structure** (inherit `BaseTest`, add `@MainActor`, add launch sequence)
4. **Add missing identifiers** — add `enum AID` entry in the production View, then add `.accessibilityIdentifier(AID.x)` to the element
5. **Add matching test IDs** — add the new constant to the appropriate enum in `Config/TestAccessibilityIDs.swift`
6. **Remove stale test IDs** that reference deleted `AID` constants
7. **Make mock data explicit** — replace implicit defaults with `TestExerciseFixture` passed via `launchDirectly(to:fixture:)`
8. **Add new test steps** for elements that were added to the screen since the test was written

### Step 3 — Review the Result

Launch `uitest-reviewer-agent` on the updated test file. Fix any remaining violations before considering the update done.
