---
name: post-change-validation
description: >-
  Validate code changes for dead code, missed reuse opportunities, and
  consistency violations. Use after refactoring, cleanup, large edits, or when
  the user asks to verify changes, check for unused code, or validate
  refactoring results.
---

# Post-Change Validation

## Context

For shared components, utilities, AppStyle tokens, and project structure see [architecture.md](../../references/architecture.md).

## When to Run

Activate this skill after any of these events:
- Refactoring (rename, extract, move, delete)
- Adding or removing a feature, view, or service
- Large multi-file edits
- User asks to "check", "verify", "validate", or "clean up" changes

## Validation Checklist

Work through each category. Use `git diff` (or the staged/unstaged diff) to identify changed files, then inspect each.

### 1. Dead Code

Search changed files and their immediate dependents for:

- **Unused imports** — `import` statements with no usage in the file
- **Unused functions/methods** — defined but never called (search project-wide)
- **Unused properties** — `let`/`var` declarations with no read access
- **Orphaned files** — files that were part of a deleted feature but not removed
- **Stale NavigationDestination cases** — enum cases no longer referenced
- **Cross-feature orphans** — when deleting a feature, also check:
  - Coordinators that orchestrate it (e.g. `TrainingCoordinator` for Training)
  - Caches that store its state (e.g. `SessionTrainingCache`)
  - Shared Components built exclusively for it (e.g. `TrainingSessionComponent`)
  - Callbacks/delegates referencing it (e.g. `TrainingCallbacks`)
  - `UIOverlayState` flags tied to the deleted feature
- **Enum case coverage** — when adding/removing an enum case, grep for all `switch`, `if case`, `guard case` on that type

How to check: For each removed or renamed symbol, grep the project for remaining references. Zero hits = dead code. For deleted features, also grep for the feature name prefix (e.g. "Training") across all folders.

### 2. Reuse Opportunities

Compare new/changed code against existing shared components and utilities:

| If you see | Consider using |
|---|---|
| Custom chip with background + stroke | `MetricChipView` |
| Full-screen sheet with header + save | `WorkoutFormSheet` |
| Expandable card with greenBlack fill | `AnalyticsDetailSection` |
| Bottom sheet with backdrop + grabber | `ExercisePickerSheetModifier` |
| Cancel/Save button row | `ExercisePickerActionButtons` |
| Wheel pickers for sets/reps/weight | `ExerciseWheelPickerRow` |
| Styled text input in a sheet | `ExercisePickerInputField` |
| Manual weight string formatting | `WeightFormatter.displayWeight(_:)` |
| Manual date logic in analytics | `AnalyticsDateHelper` |

### 3. AppStyle Consistency

Scan changed files for hardcoded values that should use tokens:

- `Color(hex: ...)`, `Color.white`, `.red`, `.gray`
- `.font(.system(size: ..., weight: ...))`
- `.padding(N)` with numeric literals
- `.cornerRadius(N)` with numeric literals
- `.opacity(N)` with numeric literals

### 4. Referential Integrity

- New views registered in `NavigationDestination` if navigable
- Deleted views removed from `NavigationDestination`
- Service API changes reflected in all calling ViewModels
- Model property changes reflected in all consumers
- New model fields on `Codable` types must be optional or have a default value (existing JSON data lacks the field)
- Enum case additions handled in every `switch` statement project-wide

### 5. Cleanup Sweep

- Resolve or remove stale `TODO` / `FIXME` comments in changed files
- Remove commented-out code blocks (dead weight after refactoring)
- Verify `print()` / debug statements are removed

### 6. State Propagation (after ViewModel/Coordinator refactoring)

When `@Published` properties are restructured (moved, renamed, wrapped in structs):

- **Combine subscribers:** Grep for `$propertyName`. If the property became computed (bridging to a nested `@Published` struct), the `$` prefix won't compile. Subscribers must observe the underlying struct.
- **Cached ViewModel sync:** Cached VMs must use a dedicated sync method (e.g. `syncExercise(_:)`) that suppresses `onUpdate` callbacks. Direct `.exercise = updated` causes re-entrant loops.
- **Equatable traps:** If a model has id-only `Equatable`, guards like `exercise != oldValue` miss content changes. Verify sync guards use `isContentEqual(to:)`.
- **objectWillChange suppression:** `didSet` guards on `@Published` must not silently swallow content-level changes due to id-only equality.
- **Conditional View rendering:** Trace mutation → `@Published` → `objectWillChange` → View body → condition switch. Any broken link = stale UI.

## Report Format

```
## Post-Change Validation Report

**Files inspected:** N files from git diff

### Dead Code
- `FileName.swift:LINE` — `unusedFunction()` has 0 references, safe to remove

### Missed Reuse
- `FileName.swift:LINE` — reimplements chip pattern, use `MetricChipView` instead

### Style Violations
- `FileName.swift:LINE` — hardcoded `.padding(16)`, use `AppStyle.Padding.card`

### Referential Issues
- `NavigationDestination` missing case for new `FeatureView`

### Cleanup
- `FileName.swift:LINE` — stale TODO from resolved task

### State Propagation
- `FileName.swift:LINE` — `$computedProperty` subscriber will not compile after refactoring

**Summary:** N dead code, N reuse, N style, N referential, N cleanup, N state propagation items found.
```
