---
name: debugging-ui-tests
description: >-
  Diagnose and fix failing XCUITest UI tests in the FitnessApp project.
  Investigate selector-not-found errors, scheme/build-config issues, fixture
  seeding mismatches after SwiftData refactors, and timing flakes. Use when a
  UI test fails, when a selector is not found, when investigating timeout
  errors, or when production-code changes broke UITestLaunchStrategy or
  test-fixture seeding.
---

# Debugging Failing UI Tests

For shared conventions (DSL, selectors, layout, **diagnosis decision tree**) see `.claude/references/ui-test-conventions.md`.

For tests that **pass** but use outdated patterns or raw API, use `updating-ui-tests` instead.

## Workflow

### Step 1 — Reproduce with the Correct Scheme

UI tests must run via the `FitnessApp UITests` scheme. The plain `FitnessApp` scheme builds without the `UITESTING` flag, which silently disables `UITestLaunchStrategy` — the app then launches with production data and **every** selector assertion fails for the wrong reason.

See `.claude/rules/build-and-test.mdc` § "UI Tests" for the exact `xcodebuild` command. Run a **single failing test** (`-only-testing:`) instead of the full suite while debugging.

### Step 2 — Diagnose the Selector

Work the **5-step decision tree** under `Diagnosing a Failing Selector` in
`.claude/references/ui-test-conventions.md` **strictly in order**:

1. Use-case flow + selector sequence understood?
2. Is the selector present in the UI hierarchy at the failure point?
3. If present → does the identifier match exactly?
4. If missing → add it on the correct UI layer (not on a wrapper that shadows it).
5. Only after 1–4 → consider timing.

**Do not skip ahead.** The most common failure mode today was jumping straight to "adjust the data pipeline" or "raise the timeout" without checking steps 1 and 2 first.

### Step 3 — If Diagnosis Points to Test Infrastructure

If steps 2–4 reveal that the selector is missing because the screen never rendered (wrong screen, no fixture data), the fix is in `FitnessApp/Shared/Navigation/UITestLaunchStrategy.swift`, not in the test or the production view.

Common cause after a SwiftData refactor: a view switched from a passed-in domain object to `@Query<XModel>` resolution by id. `prepare()` must now seed the corresponding `XModel` into the shared `Container.shared.modelContainer()` — setting an in-memory flag is no longer enough. Bridge `prepare()` and `initialNavigationStack()` via the existing `seededTrainingExerciseId` pattern (or extend it for the new screen).

### Step 4 — Re-run and Write the Stamp

Re-run the single test and confirm green. Before committing, run `/validate` so
the final tester binds `.claude/hooks/state/test-execution.stamp.md` to the
exact staged contents for pre-commit enforcement.

## Handoff

If the diagnosis reveals that a rule, skill, or hook **should have** caught this earlier but did not (e.g. today's scheme-flag gap that wasn't documented in `build-and-test.mdc`):

1. Hand off to `reviewing-agent-effectiveness` for a FIRED / NOT FIRED audit of every enforcement layer.
2. Hand off to `reviewing-agent-infrastructure` to close the identified gaps (rule prose, skill description, hook check, reference section).

This is the same bidirectional handoff pattern the two review skills already use between themselves.

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
| Selector-diagnosis tooling/steps changed | **Diagnosing a Failing Selector** section |

Also update the **Review Checklist** in `ui-test-conventions.md` if the change affects validation rules.
