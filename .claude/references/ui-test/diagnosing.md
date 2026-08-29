# Diagnosing a Failing Selector


A selector failure does not automatically mean "the selector is wrong" — it means the runner could not find the expected selector at the moment of the assertion. **Why** is the diagnostic question. Swapping the selector or bumping the timeout before diagnosing the actual cause is the most common failure mode and often hides the real bug (missing render, wrong screen, AID on the wrong UI layer).

Work the steps in order. **Do not skip ahead.**

1. **Understand the use-case flow and the selector sequence first.** What screen does the test expect? Which selectors does it interact with, in which order? Without this anchor, every later step is guesswork.
2. **Are the expected selectors actually present at the failure point?** Inspect the UI hierarchy at the moment of failure — generically via Xcode's xcresult viewer ("App element" attachment), or with the concrete fallback `xcrun xcresulttool export attachments --path <Test-*.xcresult> --output-path /tmp/uitest-attach` (the largest `*.txt` is the AX-tree). Also valid pre-run: `print(app.debugDescription)` from a temporary breakpoint in the test runner.
3. **If a selector is present:** does its identifier match exactly what the test queries for? If drift → update either `FitnessAppUITests/Selectors/AccessibilityIDs.swift` or the production `enum AID` (depending on which side was renamed unintentionally — see `Stale IDs — Keep in Sync` above).
4. **If no selector is present:** add one — and verify it ends up on the **correct UI layer**. Common layer mistakes: AID on a `VStack` wrapper while the tappable child is the actual `Button`; `accessibilityElement(children: .ignore)` on a parent that shadows the child's identifier; AID on a hidden/conditional branch that the test path never enters.
5. **Only if a correct selector is present and on the right layer:** consider timing. Try `tapOn(selector, timeout: TestDefaults.longTimeout)`. If that turns the test green, the data path is async (e.g. `@Query` materialises late); document the cause and consider whether to push the wait into production code (explicit "ready" state) instead of leaving a 10-second blanket timeout.

### Common Pitfalls

- Do not jump to "the selector is wrong" without first understanding the use-case flow and selector sequence.
- Do not raise the timeout first. Timing is step 5, not step 1 — a longer timeout often hides a layer or render-timing bug.
- Flaky ≠ selector bug. Flakes are usually render-timing or layer mistakes (AID on wrong wrapper, conditional branch never entered).
