---
name: reviewing-test-quality
description: >-
  Review unit and integration test quality in the FitnessApp project. Use when
  the user asks to review tests, check test quality, analyze test coverage,
  assess testability, find test gaps, or improve test structure. Covers
  Swift Testing (@Test/@Suite) and FitnessTestSupport conventions.
---

# Reviewing Test Quality

## Context

- **Test framework:** Swift Testing (`@Test`, `@Suite`, `#expect`, `Issue.record`)
- **Shared test utilities:** `FitnessTestSupport` package — `makeExercise()`, `MockAnalyticsStorage`, `StubAnalyticsStorage`, `waitUntil()`
- **Package structure:** Tests live under `Packages/<PackageName>/Tests/<PackageName>Tests/`
- **Build system:** Always use `xcodebuild` with `DEVELOPER_DIR` and `-skipMacroValidation` (see `build-and-test` rule)
- For domain models, services, and project structure see [architecture-documentation.md](../../references/architecture-documentation.md)

## Context Management

For reviews of multiple test files (3+), use a subagent/Task to perform the analysis in an isolated context. Return only the summary to the main conversation.

## Review Process

1. **Identify scope** — which test files to review (user-specified or all changed test files via `git diff`)
2. **Read the test files** and the production code they test
3. **Check each category** below and report findings with severity and line numbers
4. **Suggest fixes** with concrete code snippets
5. **Fix, don't just mention.** When reviewing your own tests, fix issues immediately.

## What to Check

### A: Test Style

| Pattern | Expected | Severity |
|---------|----------|----------|
| Test function without descriptive name | `@Test func <verb>_<scenario>_<expected>()` or `@Test("description")` | Warning |
| Tests not grouped in `@Suite` | Group related tests in `@Suite struct <Subject>Tests` | Warning |
| XCTest patterns (`XCTAssert*`) in Swift Testing files | Use `#expect`, `#require`, `Issue.record` | Critical |
| Missing `@MainActor` on tests touching `@MainActor` types | Add `@MainActor` to `@Suite` or individual `@Test` | Critical |
| Arrange-Act-Assert not clearly separated | Use blank lines or `// Arrange / Act / Assert` markers | Info |

### B: DRY — Shared Utilities

| Pattern | Expected | Severity |
|---------|----------|----------|
| Local `makeExercise()` factory | Use `FitnessTestSupport.makeExercise()` | Critical |
| Local `MockAnalyticsStorage` / `StubAnalyticsStorage` | Use from `FitnessTestSupport` | Critical |
| Local `waitUntil()` helper | Use `FitnessTestSupport.waitUntil()` | Critical |
| Duplicated mock/stub across test targets | Move to `FitnessTestSupport` | Warning |
| Missing `import FitnessTestSupport` when utilities are available | Add import | Warning |

### C: Assertion Strength

| Pattern | Expected | Severity |
|---------|----------|----------|
| `#expect(value != nil)` | `let unwrapped = try #require(value)` then assert on `unwrapped` | Warning |
| `#expect(array.count > 0)` | `#expect(array.count == <exact>)` or assert specific elements | Warning |
| `waitUntil` without `Issue.record` on timeout | Use shared `waitUntil()` which includes `Issue.record` | Critical |
| No negative test (only happy path) | Add test for invalid input, empty state, error case | Warning |
| `#expect(true)` or `#expect(false)` as placeholder | Replace with meaningful assertion | Critical |

### D: Coverage Gaps

Check the production code that the tests cover:

1. List all `public` / `internal` methods on ViewModels, Coordinators, UseCases, and Services
2. For each method, check if at least one test exercises it
3. Flag untested methods, prioritized by:
   - **Critical:** State-mutating methods (e.g. `completeExercise`, `editMore`, `resetExercise`)
   - **Warning:** Query methods (e.g. `getDailyWeightProgression`, `totalWeight`)
   - **Info:** Convenience/delegation methods

Also check for untested edge cases:
- Empty collections (no exercises, no analytics entries)
- Boundary values (weight = 0, sets = 0, reps = 0)
- Concurrent state changes (exercise completion during edit)

### E: Testability Hints (Production Code Issues)

Tests often reveal production code problems. Flag these:

| Pattern in Test | Production Code Problem | Severity |
|-----------------|------------------------|----------|
| Test uses `Container.shared` to set up dependencies | Production code has hard Container coupling — consider protocol injection | Warning |
| Test cannot mock a dependency (concrete class, no protocol) | Production type needs a protocol extraction | Warning |
| Test requires complex setup (> 10 lines of Arrange) | Production type has too many responsibilities — consider splitting | Info |
| Test uses `@Suite(.serialized)` without clear reason | Production code may have shared mutable state — investigate thread safety | Warning |
| Test initializes type with two different init signatures | Dual-Init pattern — consider consolidating or documenting intent | Info |

### F: Test Maintenance

| Pattern | Expected | Severity |
|---------|----------|----------|
| `Container.shared.reset()` not called in init/deinit | Add to `init()` of test suite to ensure isolation | Critical |
| Tests depend on execution order | Use `.serialized` trait explicitly or make tests independent | Critical |
| Magic numbers in assertions without context | Use named constants or comment explaining expected value | Warning |
| Test file > 300 lines without suite splitting | Split into focused `@Suite` structs | Info |

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

Overall: PASS / NEEDS WORK / CRITICAL ISSUES
```

## Running Tests After Review

After fixing test issues, run the affected package tests to verify:

```bash
cd ~/Documents/repo/FitnessApp/Packages/<Package> && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild test -scheme <Package> -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
-skipMacroValidation 2>&1 | tail -30
```

Write a test stamp to `.cursor/hooks/state/test-stamp.md` after successful execution.
