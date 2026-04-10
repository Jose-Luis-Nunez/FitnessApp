# Phase 3: Use Cases (inside existing packages)

## Prerequisite
Phase 2 (Factory DI) must be complete and building.

## Goal
Extract business logic from Views and ViewModels into dedicated Use Case types.
Use Cases live inside the existing SPM packages (convention-based, no new packages).

## Principles
- A Use Case is a single-responsibility struct/class with one `execute(...)` method.
- Use Cases receive dependencies via constructor injection (or `@Injected`).
- ViewModels call Use Cases; Views never call services directly.
- Use Cases are testable in isolation.

## Steps

### 1. Create Use Case files

Each Use Case gets its own file in a `UseCases/` folder within the relevant package:

#### FitnessStorage package
- `Packages/FitnessStorage/Sources/FitnessStorage/UseCases/DeleteWorkoutUseCase.swift`
  - Extract from `WorkoutsViewModel.deleteWorkout(_:)` and `WorkoutStorageService.deleteWorkout(_:)`
  - Logic: delete workout, handle current-workout fallback, clean up exercise files

- `Packages/FitnessStorage/Sources/FitnessStorage/UseCases/DuplicateWorkoutUseCase.swift`
  - Extract from `WorkoutStorageService.duplicateWorkout(_:)`
  - Logic: copy workout, copy all exercises per category

#### FitnessAnalytics package
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/UseCases/SaveAnalyticsUseCase.swift`
  - Extract from `AnalyticsViewModel.saveAnalytics(exerciseId:setProgress:date:)`
  - Logic: create entry, append to storage, notify observers

- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/UseCases/DeleteAnalyticsSetUseCase.swift`
  - Extract from `AnalyticsViewModel.deleteSetFromEntry(exerciseId:entryId:setIndex:)`
  - Logic: remove set, remove entry if empty, update exercise completion status

- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/UseCases/SaveOrReplaceAnalyticsUseCase.swift`
  - Extract from `AnalyticsViewModel.saveOrReplaceAnalyticsEntry(exerciseId:setProgress:date:)`
  - Logic: find existing entry for date, replace or append

#### FitnessExercise package
- `Packages/FitnessExercise/Sources/FitnessExercise/UseCases/ResetAllExercisesUseCase.swift`
  - Extract from `MuscleCategorySelectionViewModel.resetAllExercises()`
  - Logic: cancel all active sets, reset exercises across categories

### 2. Move business logic out of Views

These Views currently contain business logic that should be delegated:

| View | Current logic | Move to |
|---|---|---|
| `AddAnalyticsEntryView` | Creates `AnalyticsEntry`, calls storage directly | `SaveAnalyticsUseCase` via ViewModel |
| `ExercisePickerView` | Creates `Exercise` objects with validation | `ExerciseFormViewModel.createOrUpdateExercise()` (already exists, verify it's used) |
| `ScheduleCalendarView` | Date filtering logic | Keep (pure UI filtering is acceptable) |
| `TrainingPickerComponent` | Set editing + save logic | `TrainingCoordinator` (already delegates, verify) |

### 3. Update ViewModels to use Use Cases

Example transformation:

```swift
// BEFORE (in AnalyticsViewModel)
public func saveAnalytics(exerciseId: UUID, setProgress: [SetProgress], date: Date = Date()) {
    guard !setProgress.isEmpty else { return }
    let analyticsEntry = AnalyticsEntry(...)
    var existingEntries = storageService.load(for: exerciseId)
    existingEntries.append(analyticsEntry)
    storageService.save(existingEntries, for: exerciseId)
    lastUpdatedExerciseId = exerciseId
}

// AFTER
public func saveAnalytics(exerciseId: UUID, setProgress: [SetProgress], date: Date = Date()) {
    saveAnalyticsUseCase.execute(exerciseId: exerciseId, setProgress: setProgress, date: date)
    lastUpdatedExerciseId = exerciseId
}
```

### 4. Register Use Cases in Factory Container

```swift
extension Container {
    var deleteWorkout: Factory<DeleteWorkoutUseCase> {
        self { DeleteWorkoutUseCase() }
    }
    var duplicateWorkout: Factory<DuplicateWorkoutUseCase> {
        self { DuplicateWorkoutUseCase() }
    }
    var saveAnalytics: Factory<SaveAnalyticsUseCase> {
        self { SaveAnalyticsUseCase() }
    }
    // ... etc
}
```

## Verification
- No business logic remains directly in View `body` or View methods.
- Each Use Case has a single `execute(...)` entry point.
- ViewModels are thin orchestrators (call Use Case, update published state).
- All Use Cases are independently testable.
- App builds and behaves identically to before.
