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

### Step 1 + 2 — Review Test and Check Production Code (parallel)

Launch both agents in parallel:

- `uitest-reviewer-agent` on the existing test file — reports convention violations (raw API usage, hardcoded strings, structure issues, selector mismatches)
- `uitest-prep-agent` with the existing test file as input — checks whether identifiers still exist in production, finds new untested elements, and flags stale selectors

Both agents are read-only. **You** apply all fixes in Step 3.

### Step 2 — Fix and Extend

Based on both agent reports, apply fixes:

1. **Replace raw API** with DSL functions (`tapOn`, `verifyExists`, etc.)
2. **Replace hardcoded strings** with Selector constants
3. **Fix structure** (inherit `BaseTest`, add `@MainActor`, add launch sequence)
4. **Add missing identifiers** in production Views (`.accessibilityIdentifier("id_...")`)
5. **Add missing Selectors** to the appropriate enum
6. **Remove stale Selectors** that reference deleted production elements
7. **Add new test steps** for elements that were added to the screen since the test was written

### Step 3 — Review the Result

Launch `uitest-reviewer-agent` on the updated test file. Fix any remaining violations before considering the update done.
