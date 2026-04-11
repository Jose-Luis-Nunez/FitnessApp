# Phase 5: Training Use Cases

## Prerequisite
Phase 3 (Use Cases for Storage, Analytics, Exercise) and Phase 4 (SwiftData Migration) must be complete.

## Goal
Extract business logic from `TrainingCoordinator` into dedicated Use Case types, so the coordinator becomes a thin state-holder + orchestrator — consistent with the Use Case pattern already established in other packages.

## Problem
`TrainingCoordinator` currently has three responsibilities:

1. **State-Holder** — `currentExercise`, `isTrainingActive`, `lastCompletedExercise`, `activeSetViewModel`
2. **Business Logic** — set completion rules, exercise completion rules, analytics saving, session management
3. **UI Bridge** — `createBottomActionBarViewModel()`, `createTrainingCallbacks()`

Responsibility 2 should be in Use Cases. The coordinator should only hold state (1) and wire UI callbacks to Use Cases (3).

## Use Cases to Extract

### FitnessTraining package

All Use Cases go to `Packages/FitnessTraining/Sources/FitnessTraining/UseCases/`.

#### 1. `StartTrainingUseCase`
- **Extract from:** `TrainingCoordinator.startTraining(for:)`
- **Logic:** Determine if resuming existing session or starting fresh, initialize ActiveSetViewModel, set training state
- **Input:** `Exercise`, `ActiveSetViewModel`
- **Output:** Updated training state (currentExercise, isTrainingActive)

#### 2. `CompleteSetUseCase`
- **Extract from:** `TrainingCoordinator.completeSet()`
- **Logic:** Validate set can be completed (not past max sets, not already last), stop timer, complete current set, start next if not last
- **Input:** `ActiveSetViewModel`
- **Output:** Set completed, next set started (or last set flagged)

#### 3. `FinishExerciseUseCase`
- **Extract from:** `TrainingCoordinator.finishExercise()`
- **Logic:** Stop timer, save analytics, mark exercise as completed if last set done, clean up ActiveSetViewModel state
- **Input:** `ActiveSetViewModel`, `AnalyticsViewModel`, exercise update callback
- **Output:** Exercise completed (or not), analytics saved, training state cleared
- **Note:** This is the most complex Use Case — it coordinates analytics, exercise state, and UI state

#### 4. `CancelTrainingUseCase`
- **Extract from:** `TrainingCoordinator.cancelTraining()`
- **Logic:** Cancel active set, clear training state
- **Input:** `ActiveSetViewModel`
- **Output:** Training state cleared

#### 5. `ResetExerciseUseCase`
- **Extract from:** `TrainingCoordinator.resetExercise()`
- **Logic:** Stop timer, call exercise reset callback, reset progress, clear training state
- **Input:** `ActiveSetViewModel`, exercise reset callback
- **Output:** Exercise reset, training state cleared

## Steps

### 1. Create Use Case files

Each Use Case is a `@MainActor` struct with a single `execute(...)` method. Dependencies are injected via `@Injected`.

Example pattern (consistent with existing Use Cases):

```swift
import Foundation
import FitnessCore
import Factory

@MainActor
public struct FinishExerciseUseCase {
    @Injected(\.analyticsStorage) private var analyticsStorage

    public init() {}

    public func execute(
        activeSetViewModel: ActiveSetViewModel,
        findCategory: (Exercise) -> MuscleCategoryGroup?,
        onExerciseUpdate: (Exercise, MuscleCategoryGroup) -> Void
    ) -> Exercise? {
        activeSetViewModel.stopTimer()

        guard let exercise = activeSetViewModel.currentExercise,
              let category = findCategory(exercise) else { return nil }

        // Save analytics
        if !activeSetViewModel.setProgress.isEmpty {
            let entry = AnalyticsEntry(
                exerciseId: exercise.id,
                date: Date(),
                setProgress: activeSetViewModel.setProgress
            )
            var entries = analyticsStorage.load(for: exercise.id)
            entries.append(entry)
            analyticsStorage.save(entries, for: exercise.id)
        }

        // Mark completed if all sets done
        var completedExercise: Exercise? = nil
        if activeSetViewModel.isLastSetCompleted {
            var updated = exercise
            updated.isCompleted = true
            onExerciseUpdate(updated, category)
            completedExercise = updated
        }

        activeSetViewModel.finishExercise()
        activeSetViewModel.quickDoneModeActive = false

        return completedExercise
    }
}
```

### 2. Slim down TrainingCoordinator

After extraction, the coordinator methods become thin wrappers:

```swift
public func finishExercise() {
    if let completed = finishExerciseUseCase.execute(
        activeSetViewModel: activeSetViewModel,
        findCategory: findCategory,
        onExerciseUpdate: onExerciseUpdate
    ) {
        lastCompletedExercise = completed
    }
    currentExercise = nil
    isTrainingActive = false
}
```

The coordinator keeps:
- State properties (`currentExercise`, `isTrainingActive`, `lastCompletedExercise`, `activeSetViewModel`)
- UI bridge methods (`createBottomActionBarViewModel`, `createTrainingCallbacks`)
- Delegation to Use Cases

### 3. Register Use Cases in Factory Container

Add to `TrainingContainer.swift`:

```swift
var startTrainingUseCase: Factory<StartTrainingUseCase> {
    self { MainActor.assumeIsolated { StartTrainingUseCase() } }
}
var completeSetUseCase: Factory<CompleteSetUseCase> {
    self { MainActor.assumeIsolated { CompleteSetUseCase() } }
}
var finishExerciseUseCase: Factory<FinishExerciseUseCase> {
    self { MainActor.assumeIsolated { FinishExerciseUseCase() } }
}
var cancelTrainingUseCase: Factory<CancelTrainingUseCase> {
    self { MainActor.assumeIsolated { CancelTrainingUseCase() } }
}
var resetExerciseUseCase: Factory<ResetExerciseUseCase> {
    self { MainActor.assumeIsolated { ResetExerciseUseCase() } }
}
```

### 4. Update TrainingCoordinator to use Use Cases

Replace direct logic with Use Case calls via `@Injected`.

### 5. Fix Service Locator in WorkoutStorageService

`WorkoutStorageService` uses a lazy Service Locator for `exerciseStorage`:

```swift
// CURRENT (lazy Service Locator — resolves at runtime, not at init)
@ObservationIgnored
private lazy var exerciseStorage: ExerciseStoring = Container.shared.exerciseStorage()
```

This was a workaround because `@Injected` + `@ObservationIgnored` on `@Observable` classes caused an init-order bug (`defaultWorkout` was nil after init). The fix:

- Inject `ExerciseStoring` via the init parameter (constructor injection), consistent with 7c
- `WorkoutStorageService.init(defaults:)` becomes `WorkoutStorageService.init(defaults:exerciseStorage:)`
- Factory registration passes the dependency explicitly
- Removes the last Service Locator from the storage layer

### 6. Update Tests

- Existing `TrainingCoordinatorTests` should still pass (coordinator behavior unchanged from outside)
- Add unit tests for each Use Case in isolation
- Use Cases are easier to test than the coordinator because they have no state — pure input/output
- Update `WorkoutStorageServiceTests` to inject mock `ExerciseStoring` if needed

## Verification
- `TrainingCoordinator` has no business logic — only state + delegation
- Each Use Case has a single `execute(...)` entry point
- All existing tests pass (behavior unchanged)
- New Use Case tests cover edge cases
- No Service Locator pattern (`Container.shared.xxx()`) remains in any service — all dependencies injected via init or `@Injected`
- App builds and behaves identically to before
- Consistent with the Use Case pattern in FitnessStorage, FitnessAnalytics, FitnessExercise
