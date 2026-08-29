# UI Test Reference

Shared conventions for writing and updating UI tests.

Before using these implementation conventions, apply
`.claude/references/test-selection-policy.md`. UI coverage is selected only when
a critical journey or platform integration cannot be protected more cheaply at
a deterministic lower layer. Existing UI tests must pass the same retention
gate before repair or expansion.

Run `bash .claude/hooks/lib/test-domain-risk.sh classify worktree` first.
Training/Exercise paths are blocker, Workouts/Analytics are high, and
Profile/Feedback are low. The highest affected domain wins; technical risk may
raise but never lower the result.

## Routing

Read only what the task needs. Loaded whole this file is roughly three times the
cost of a routed read, and the sections you skip would not have changed a single
decision.

| Task | Read |
|---|---|
| Adding or renaming a testable element in a view | `ui-test/identifiers.md` |
| Writing a new UI test | `ui-test/authoring.md`, then `ui-test/dsl.md` |
| Seeding state, or jumping straight to a screen | `ui-test/fixtures-navigation.md` |
| A selector is not found, or a test times out | `ui-test/diagnosing.md` |
| Refactoring or reviewing an existing UI test | `ui-test/review-checklist.md`, `ui-test/dsl.md` |

All six live in `.claude/references/ui-test/`.
