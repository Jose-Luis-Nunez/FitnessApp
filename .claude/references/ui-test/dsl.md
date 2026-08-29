# DSL and Constraints

The helper API and the rules that forbid raw XCUITest in tests.

## DSL Function Reference

| Action | DSL Function |
|--------|-------------|
| Tap an element | `tapOn(_:)` or `tapOn(label:)` |
| Tap the first element whose ID has a prefix | `tapOnWithPrefix(_:)` |
| Tap if it might not appear | `tapOnIfExists(_:)` |
| Swipe within a specific element | `swipeUpOn(_:)` / `swipeDownOn(_:)`; downward handle drags use a deterministic 120-pt travel distance |
| Select or activate a native wheel row | `selectPickerWheelValue(_:value:)` / `tapSelectedPickerWheelRow(_:)` |
| Type into a text field | `fill(_:with:)` |
| Type into a picker input button | `fillPickerInput(_:with:)` |
| Assert element is visible | `verifyExists(_:)` |
| Assert enabled state | `verifyIsEnabled(_:)` / `verifyIsDisabled(_:)` |
| Assert a system-controlled menu option is visible by label | `verifyExists(label:)` |
| Assert element is gone | `verifyNotExists(_:)` |
| Assert element exists by ID prefix | `verifyExistsWithPrefix(_:)` |
| Assert no element with ID prefix | `verifyNotExistsWithPrefix(_:)` |
| Read element frames | `frameOf(_:)` / `framesOfElements(withPrefix:limit:)` |
| Sort measured frames by visual reading order | `sortFramesInReadingOrder(_:)` |
| Attach a diagnostic full-screen screenshot | `attachDiagnosticScreenshot(named:)` |
| Assert element label content | `verifyLabel(_:equals:)` |
| Assert element accessibility value | `verifyValue(_:equals:)` |
| Assert prefixed element value content | `verifyValueContainsWithPrefix(_:expectedComponents:)` |
| Wait for label to be populated | `waitForNonEmptyLabel(_:)` |
| Scroll until a later or earlier element is visible | `swipeUpUntilVisible(_:)` / `swipeDownUntilVisible(_:)` |

If no function exists for the interaction, **add it to `ElementActions.swift`** following existing patterns (timeout, `findElement`, predicate-based waits).

## Timeout Defaults

All DSL functions use `TestDefaults` for consistent timeouts:

| Constant | Value | Usage |
|----------|-------|-------|
| `TestDefaults.timeout` | 5.0s | Standard wait for elements |
| `TestDefaults.shortTimeout` | 2.0s | Disappearance checks, optional elements |
| `TestDefaults.longTimeout` | 10.0s | Slow-loading screens |

Override per call site when needed: `tapOn(selector, timeout: TestDefaults.longTimeout)`.

## Constraints

### Always Use DSL -- Never Raw XCUITest API in Tests

```swift
// BAD
let tile = app.descendants(matching: .any)
    .matching(identifier: "id_category_tile_arms")
    .firstMatch
tile.tap()

// GOOD
tapOn(HomeIDs.categoryTile(for: "arms"))
```

### Test ID Constants -- Never Hardcode Strings in Tests

```swift
// BAD
tapOn("id_button_start")

// GOOD
tapOn(TrainingIDs.startButton)
```

### Element Identification Priority

1. **`accessibilityIdentifier`** -- most reliable, language-independent
2. **`label:`** -- only for system controls without identifier
3. **`NSPredicate`** -- avoid; only if pattern matching is truly required

Never resort to predicates or labels when an identifier can be added to the production code.

### Stale IDs -- Keep in Sync

When a production identifier is renamed or deleted, update `Selectors/AccessibilityIDs.swift` to match. Stale constants that reference non-existent IDs cause test failures.
