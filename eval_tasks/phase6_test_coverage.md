# Phase 6: Test Coverage

## Prerequisite
Phases 1–5 should be complete, but test writing can begin alongside Phase 5.

## Goal
Achieve comprehensive unit and integration test coverage for all ViewModels, Use Cases, and Services.

## Current Test State

Existing test files (project tests, excluding SPM checkout tests):

| File | Covers |
|---|---|
| `ExerciseCardViewModelTests.swift` | `ExerciseCardViewModel` |
| `MuscleCategoryViewModelTests.swift` | `MuscleCategoryViewModel` |
| `TrainingCoordinatorTests.swift` | `TrainingCoordinator` |
| `SessionTrainingCacheTests.swift` | `SessionTrainingCache` |
| `AnalyticsViewModelTests.swift` | `AnalyticsViewModel` |
| `EnvironmentObjectContractTests.swift` | Environment injection contract |
| `TrainingUITests.swift` | UI test for training flow |

## Missing Test Coverage

### Priority 1 — Services (data layer)

These have **no tests** and handle persistence:

- `WorkoutStorageServiceTests.swift` — CRUD operations, current-workout management, duplicate
- `ExerciseStorageServiceTests.swift` — load/save per workout+category, migration from old format
- `AnalyticsStorageServiceTests.swift` — load/save/append analytics per exercise
- `TotalAnalyticsStorageServiceTests.swift` — aggregate analytics queries
- `ExerciseManagementServiceTests.swift` — exercise CRUD, reset, cross-service coordination

Each service test should use a mock `ModelContext` (after Phase 4) or temporary directory (before Phase 4).

### Priority 2 — ViewModels without tests

- `WorkoutsViewModelTests.swift` — add/delete/rename/duplicate workout, current workout switching
- `ExerciseFormViewModelTests.swift` — form validation, create/update exercise
- `MuscleCategorySelectionViewModelTests.swift` — selection state, reset all, multi-category
- `ActiveSetViewModelTests.swift` — set progress cycling, weight/reps tracking
- `ScheduleViewModelTests.swift` — calendar data, weekly/monthly grouping
- `TotalAnalyticsViewModelTests.swift` — aggregation, category progress

### Priority 3 — Use Cases (after Phase 3)

Each Use Case introduced in Phase 3 needs its own test file:

- `DeleteWorkoutUseCaseTests.swift`
- `DuplicateWorkoutUseCaseTests.swift`
- `SaveAnalyticsUseCaseTests.swift`
- `DeleteAnalyticsSetUseCaseTests.swift`
- `SaveOrReplaceAnalyticsUseCaseTests.swift`
- `ResetAllExercisesUseCaseTests.swift`

### Priority 4 — Integration Tests

- `DataMigrationServiceTests.swift` — verify JSON → SwiftData migration (after Phase 4)
- `TimerServiceTests.swift` — timer start/stop/tick accuracy

## Testing Patterns

### Mock via Factory (after Phase 2)

```swift
final class WorkoutsViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Container.shared.reset()
        Container.shared.workoutStorage.register { MockWorkoutStorageService() }
    }

    func testDeleteWorkout() async {
        let vm = WorkoutsViewModel()
        vm.deleteWorkout(at: IndexSet(integer: 0))
        XCTAssertEqual(vm.workouts.count, expectedCount)
    }
}
```

### Async test pattern (Swift Testing)

Consider using Swift Testing (`import Testing`) for new tests:

```swift
@Test func saveAnalyticsCreatesEntry() async {
    let useCase = SaveAnalyticsUseCase(storage: MockAnalyticsStorage())
    useCase.execute(exerciseId: .init(), setProgress: [.init(...)], date: .now)
    #expect(storage.savedEntries.count == 1)
}
```

### Naming convention

- Test files: `<TypeUnderTest>Tests.swift`
- Test methods: `test<Behavior>` (XCTest) or descriptive name (Swift Testing)
- One assertion focus per test method

## Verification
- Every ViewModel has a corresponding test file
- Every Use Case has a corresponding test file
- Every storage service has a corresponding test file
- All tests pass
- No test depends on real file system or UserDefaults (use mocks/temp directories)
- Test coverage report shows > 80% for business logic
