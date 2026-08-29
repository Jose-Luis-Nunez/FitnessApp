# Core Test Checks

Always apply these four tables. They are cheap and catch the common defects.

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

### F: Test Maintenance

| Pattern | Expected | Severity |
|---------|----------|----------|
| `Container.shared.reset()` not called in init/deinit | Add to `init()` of test suite to ensure isolation | Critical |
| Tests depend on execution order | Use `.serialized` trait explicitly or make tests independent | Critical |
| Magic numbers in assertions without context | Use named constants or comment explaining expected value | Warning |
| Test file > 300 lines without suite splitting | Split into focused `@Suite` structs | Info |
