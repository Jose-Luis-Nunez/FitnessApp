# Phase 2: Dependency Injection — Factory

## Prerequisite
Phase 1 (`@Observable` migration) must be complete and building.

## Goal
Replace all `.shared` singletons and internal service construction with
[hmlongco/Factory](https://github.com/hmlongco/Factory) DI container.

## Steps

### 1. Add Factory dependency
- Add `hmlongco/Factory` SPM package to the project (latest version).
- Add `Factory` as a dependency to all packages that need it:
  `FitnessStorage`, `FitnessExercise`, `FitnessAnalytics`,
  `FitnessSchedule`, `FitnessTraining`, and the main `FitnessApp` target.

### 2. Create DI Container
- Create `FitnessApp/DI/AppContainer.swift`.
- Register all services as Factory containers:

```swift
import Factory
import FitnessStorage
import FitnessExercise
import FitnessAnalytics
import FitnessTraining

extension Container {
    var workoutStorage: Factory<WorkoutStorageService> {
        self { WorkoutStorageService.shared }.singleton
    }
    var exerciseStorage: Factory<ExerciseStorageService> {
        self { ExerciseStorageService() }
    }
    var analyticsStorage: Factory<AnalyticsStorageService> {
        self { AnalyticsStorageService() }
    }
    var exerciseManagement: Factory<ExerciseManagementService> {
        self { ExerciseManagementService() }
    }
    var totalAnalyticsStorage: Factory<TotalAnalyticsStorageService> {
        self { TotalAnalyticsStorageService() }
    }
    var sessionTrainingCache: Factory<SessionTrainingCache> {
        self { SessionTrainingCache.shared }.singleton
    }
}
```

### 3. Replace `.shared` references (18+ sites)
For each ViewModel/Service that currently uses `.shared` or creates services internally:

| Current pattern | New pattern |
|---|---|
| `WorkoutStorageService.shared` | `@Injected(\.workoutStorage) var workoutStorage` |
| `ExerciseStorageService()` (created in init) | `@Injected(\.exerciseStorage) var exerciseStorage` |
| `AnalyticsStorageService()` (created in init) | `@Injected(\.analyticsStorage) var analyticsStorage` |
| `SessionTrainingCache.shared` | `@Injected(\.sessionTrainingCache) var cache` |
| `ExerciseManagementService()` (created in init) | `@Injected(\.exerciseManagement) var management` |

Files to update:
- `WorkoutsViewModel.swift` — `storageService: WorkoutStorageService = .shared`
- `MuscleCategoryViewModel.swift` — `workoutStorageService: WorkoutStorageService = .shared`, `ExerciseStorageService()`, `SessionTrainingCache.shared`
- `MuscleCategorySelectionViewModel.swift` — `workoutStorageService: WorkoutStorageService = .shared`, `ExerciseManagementService()`
- `AnalyticsViewModel.swift` — `AnalyticsStorageService()`, `ExerciseStorageService()`, `WorkoutStorageService.shared`
- `TotalAnalyticsViewModel.swift` — `TotalAnalyticsStorageService()`
- `ScheduleViewModel.swift` — `TotalAnalyticsViewModel()`
- `ExerciseManagementService.swift` — `ExerciseStorageService()`, `AnalyticsStorageService()`, `.shared`
- `TotalAnalyticsStorageService.swift` — `AnalyticsStorageService()`, `ExerciseStorageService()`, `.shared`
- `ExerciseStorageService.swift` — `WorkoutStorageService.shared` in `loadForWorkout`
- `WorkoutStorageService.swift` — remove `static let shared` (replaced by container singleton)
- `SessionTrainingCache.swift` — remove `static let shared`
- `TrainingView.swift` — `ExerciseManagementService()`, `SessionTrainingCache.shared`
- `MuscleCategoryView.swift` — `MuscleCategoryViewModel(group:)`
- `MuscleCategorySelectionView.swift` — `MuscleCategorySelectionViewModel()`, `ExerciseManagementService()`

### 4. Remove `static let shared` definitions
Once all references go through Factory, remove:
- `WorkoutStorageService.shared`
- `SessionTrainingCache.shared`

### 5. Update tests
- Use `Container.shared.reset()` in test setup.
- Register mock implementations via `Container.shared.myService.register { MockService() }`.

## Verification
- App builds without errors.
- All `.shared` references removed from source (only in Container registration).
- No service constructed directly in ViewModels (all via `@Injected`).
- Tests pass with mocked dependencies.

## Decision Record
- **DI Framework:** Factory (hmlongco/Factory)
- **Decided in:** Architecture Evaluation chat (April 2026)
- **Reason:** Lightweight, property-wrapper based, no code generation, Swift-native.
