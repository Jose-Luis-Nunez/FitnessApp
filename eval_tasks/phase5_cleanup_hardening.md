# Phase 5: Cleanup & Hardening

## Prerequisite
Phase 4 (SwiftData) should be complete, but most items here can be done independently.

## Goal
Fix remaining anti-patterns and code quality issues identified in the architecture evaluation.

## Items

### 1. Fix `ForEach` index iteration (7 sites)

Replace `ForEach` using indices/enumerated with `Identifiable`-based iteration.

| File | Line | Current pattern | Fix |
|---|---|---|---|
| `InactiveCardView.swift` | ~154 | `ForEach(cachedSetProgress.indices, id: \.self)` | Make `SetProgress` conform to `Identifiable`, use `ForEach(cachedSetProgress)` |
| `SimpleActiveSetView.swift` | ~18 | `ForEach(setProgress.indices, id: \.self)` | Same — use `Identifiable` `SetProgress` |
| `IdleActiveCardView.swift` | ~320 | `ForEach(0..<(3 - weightPhases.count), id: \.self)` | OK (static range for placeholder slots) |
| `TotalAnalyticsView.swift` | ~329 | `ForEach(Array(...enumerated()), id: \.offset)` | Add `Identifiable` to `TrainingRhythmDetailData` dates wrapper |
| `TotalAnalyticsView.swift` | ~427, ~471 | `ForEach(Array(...enumerated()), id: \.offset)` | Add `Identifiable` to `CategoryProgressData` / `ExerciseProgressData` |
| `AnalyticsView.swift` | ~151, ~291 | `ForEach(Array(...enumerated()), id: \.offset)` | Add `id` to chart data points; `SetProgress` gets `Identifiable` |
| `MiniActionMenuView.swift` | ~93 | `ForEach(items.indices, id: \.self)` | Make `MiniActionMenuItem` conform to `Identifiable` |
| `AddAnalyticsEntryView.swift` | ~84 | `ForEach(Array(sets.enumerated()), id: \.element.id)` | OK (already uses element id) |

### 2. Replace `print` in `catch` blocks with proper error handling

Define a `StorageError` enum in `FitnessStorage`:

```swift
public enum StorageError: Error, LocalizedError {
    case encodingFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case fileNotFound(path: String)
    case writeFailed(underlying: Error)
}
```

Update these files to use `throws` propagation instead of `print`:

| File | Sites | Current | New |
|---|---|---|---|
| `ExerciseStorageService.swift` | 7 `print` calls | `print("Failed to...")` | `throws StorageError` or log via `os.Logger` |
| `AnalyticsStorageService.swift` | 3 `print` calls | `print("Failed to...")` | `throws StorageError` or log via `os.Logger` |
| `WorkoutStorageService.swift` | 2 `try?` sites | `try? JSONEncoder().encode(...)` | `do/catch` with logging |

Decision: Use `os.Logger` for non-fatal file-not-found, `throws` for actual failures.

### 3. Fix `Workout` decode resilience

In `WorkoutStorageService.loadWorkouts()`:
```swift
// BEFORE
if let decoded = try? JSONDecoder().decode([Workout].self, from: data) {

// AFTER  
do {
    let decoded = try JSONDecoder().decode([Workout].self, from: data)
    workouts = decoded
} catch {
    Logger.storage.error("Failed to decode workouts: \(error)")
}
```

### 4. Move `MuscleCategoryGroup.displayName` to FitnessUI

Currently `MuscleCategoryGroup` in `FitnessCore` imports `FitnessResources` for `L10n` strings.
This violates "Domain depends on nothing."

Fix:
- Remove `displayName` computed property from `MuscleCategoryGroup` in FitnessCore
- Add extension in `FitnessUI`: `extension MuscleCategoryGroup { var displayName: String { ... } }`
- Update all call sites to import from `FitnessUI` context

### 5. Re-inject environment in sheets (check all sites)

With `@Observable` + `@Environment`, sheets automatically inherit the environment.
Verify these files don't have missing environment injection:

| File | Sheet type |
|---|---|
| `WorkoutsScreen.swift` | `.fullScreenCover` (CreateWorkoutView, RenameWorkoutView) |
| `MuscleCategoryView.swift` | `.sheet` (ExercisePickerView) |
| `MuscleCategorySelectionView.swift` | `.sheet` (ExercisePicker) |
| `TrainingView.swift` | No sheets (OK) |

Test: Open each sheet and verify `@Environment` values are accessible.

### 6. Split large View files

Files over 400 lines should be split into focused components:

| File | Lines | Suggested split |
|---|---|---|
| `MuscleCategorySelectionView.swift` | ~625 | Extract `SelectionOverviewGrid`, `SelectionListMode`, `SelectionMiniMenu` |
| `TotalAnalyticsView.swift` | ~530 | Extract `AnalyticsTileGrid`, `CategoryProgressSection`, `TrainingRhythmSection` |
| `AnalyticsViewModel.swift` | ~547 | Extract `WeightAnalytics` extension, `RepsAnalytics` extension (already partially done) |
| `MuscleCategoryView.swift` | ~350 | Extract `CategoryMiniMenu`, `CategoryExerciseList` |
| `ExercisePickerView.swift` | ~300 | Borderline — consider extracting `ExercisePickerHeader` |

Priority: Start with files > 400 lines.

## Verification
- No `ForEach` with `.indices` or `.enumerated()` where `Identifiable` is possible
- No `print` in catch blocks (use `os.Logger` or `throws`)
- No `try?` that silently swallows errors
- `MuscleCategoryGroup` in FitnessCore has no import of FitnessResources
- All sheets have correct environment values
- No View file exceeds ~300 lines
