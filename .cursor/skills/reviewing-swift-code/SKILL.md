---
name: reviewing-swift-code
description: >-
  Review Swift/SwiftUI code for architecture violations in the FitnessApp
  project. Use when the user asks to review code, check conventions, audit
  styling, verify architecture compliance, find dead code, detect unused
  imports, or validate refactoring cleanup of Swift files.
---

# Reviewing Swift Code

## Context

For domain models, services, shared components, and project structure see [architecture.md](../../references/architecture.md).

## Context Management

For reviews of large files (500+ lines) or multiple files (2+), use a subagent/Task to perform the analysis in an isolated context. Return only the summary to the main conversation. This keeps the primary context window clean for follow-up work.

## Review Process

1. **Read the file(s)** the user wants reviewed.
2. **Check each category** below and report violations with line numbers.
3. **Suggest fixes** using the correct AppStyle token or shared component.

## What to Check

### Hardcoded Styling (highest priority)

Search for these patterns and flag them:

| Pattern | Should Be |
|---------|-----------|
| `Color(hex: "...")` | `AppStyle.Color.<token>` |
| `Color.white`, `.red`, `.gray` | `AppStyle.Color.white`, add token if missing |
| `.font(.system(size: N, weight: .W))` | `AppStyle.Font.<token>` |
| `.padding(N)`, `.padding(.edge, N)` | `AppStyle.Padding.<token>` |
| `.cornerRadius(N)` | `AppStyle.CornerRadius.<token>` |
| `.opacity(N)` | `AppStyle.Opacity.<token>` |

If no matching token exists, recommend adding one to `AppStyle.swift` with a semantic name.

### Duplicated UI Patterns

Flag code that reimplements existing shared components (see Shared Components table in [architecture.md](../../references/architecture.md) for full list with file paths and parameters):

- Chip with background + stroke + cornerRadius -> `MetricChipView`
- Full-screen sheet with drag indicator + header + save -> `WorkoutFormSheet`
- Analytics expandable card with greenBlack fill -> `AnalyticsDetailSection`
- Bottom picker sheet with backdrop + grabber -> `ExercisePickerSheetModifier`
- Cancel/Save button row in pickers -> `ExercisePickerActionButtons`
- Sets/Reps/Weight wheel pickers -> `ExerciseWheelPickerRow`
- Styled text input in sheets -> `ExercisePickerInputField`

### Utility Usage

- Weight formatting without `WeightFormatter.displayWeight(_:)` (look for `String(format: "%.1f"` + `replacingOccurrences` or manual `"kg"` concatenation)
- Date logic in analytics without `AnalyticsDateHelper` (look for `Calendar.current`, `DateFormatter` in analytics files)

### MVVM Violations

- Business logic (data manipulation, service calls, storage access) in View `body` or computed view properties
- ViewModel not using `ObservableObject` + `@Published`
- View creating services directly instead of going through ViewModel

### Navigation

- Navigation via manual `NavigationLink` instead of `navigationPath.append(NavigationDestination.<case>)`
- Missing `NavigationDestination` case for new screens

## Report Format

Group findings by category. For each violation:

```
**[Category]** `FileName.swift:LINE`
  Found: <what the code does>
  Fix: <specific replacement using AppStyle/shared component>
```

End with a summary count: N styling violations, N duplications, N utility issues, N MVVM issues, N navigation issues.
