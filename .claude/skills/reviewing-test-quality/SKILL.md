---
name: reviewing-test-quality
description: >-
  Review unit and integration test quality in the FitnessApp project. Use when
  the user asks to review tests, check test quality, analyze test coverage,
  assess testability, find test gaps, or improve test structure. Covers
  Swift Testing (@Test/@Suite) and FitnessTestSupport conventions.
---

# Reviewing Test Quality

Before reviewing coverage or test mechanics, run
`bash .claude/hooks/lib/test-domain-risk.sh classify worktree` and apply
`.claude/references/test-selection-policy.md`. The domain tier is the baseline;
technical risk may raise but never lower it.

## Context

- **Test framework:** Swift Testing (`@Test`, `@Suite`, `#expect`, `Issue.record`)
- **Shared test utilities:** `FitnessTestSupport` package — `makeExercise()`, `MockAnalyticsStorage`, `StubAnalyticsStorage`, `waitUntil()`
- **Package structure:** Tests live under `Packages/<PackageName>/Tests/<PackageName>Tests/`
- **Build system:** Always use `xcodebuild` with `DEVELOPER_DIR` and `-skipMacroValidation` (see `build-and-test` rule)
- For domain models, services, and project structure, read only the relevant
  heading in `.claude/references/architecture-documentation.md`

## Context Management

For reviews of multiple test files (3+), use a subagent/Task to perform the analysis in an isolated context. Return only the summary to the main conversation.

## Review Process

1. **Identify scope** — which test files to review (user-specified or all changed test files via `git diff`)
2. **Read the test files** and the production code they test
3. **Check each category** below and report findings with severity and line numbers
4. **Suggest fixes** with concrete code snippets
5. **Fix, don't just mention.** When reviewing your own tests, fix issues immediately.

## What to Check

Always read `references/core-checks.md` — test style, shared-utility DRY,
assertion strength, and maintenance. Then read only the references the reviewed
tests actually match:

| Signal in the reviewed tests | Reference |
|---|---|
| Judging whether production behavior is covered at all | `coverage-gaps.md` |
| `Container.shared`, `.serialized`, hand-rolled `on*` closures, mocks pre-writing end state | `testability.md` |
| `Task.sleep`, slow suites, parallelism questions | `performance.md` |
| `assertSnapshot`, `__Snapshots__`, baseline PNGs | `snapshots.md` |

Do not read all five. Routing is why this skill stays affordable: loaded whole
it is roughly four times the cost of a routed review, and the sections you skip
would not have changed a single finding.

## Report Format

Group findings by category. For each finding:

```
**[Category:Severity]** `TestFile.swift:LINE`
  Found: <what the test does wrong>
  Fix: <specific replacement with code snippet>
```

End with a summary:

```
## Summary
- A (Test Style): N findings (N critical, N warning, N info)
- B (DRY): N findings
- C (Assertion Strength): N findings
- D (Coverage Gaps): N untested methods
- E (Testability Hints): N production code issues
- F (Test Maintenance): N findings
- G (Performance Smells): N findings (parallelism ratio per package)
- H (Snapshot Tests): N findings

Overall: PASS / NEEDS WORK / CRITICAL ISSUES
```

## Running Tests After Review

After fixing test issues, run the affected package tests to verify:

```bash
scripts/test-affected-packages.sh <Package>
```

The runner selects native-fast, pinned-iOS integration, and snapshot phases
from one shared SwiftPM graph. Xcode owns global build-job and test-worker
coordination. Use `--jobs 1` only when diagnosing contention; do not start
parallel package-level `xcodebuild` processes.

Write a test stamp to `.claude/hooks/state/test-execution.stamp.md` after successful execution.
