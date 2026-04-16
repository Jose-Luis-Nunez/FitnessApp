# FitnessApp Architecture

## Feature Map

```
Features/
  Analytics/          — Exercise analytics, charts, total analytics overview
  BottomBar/          — Bottom navigation bar, bottom action bar
    Profile/          — User profile: nickname, body data (weight/height/age), BMI via API
  Exercise/
    ActiveSet/        — Active set tracking during training, timer service
    ExerciseCard/     — Card UI for exercises (idle, active, inactive states)
    MuscleCategory/   — Muscle category detail screen with exercises
    Storage/          — Exercise persistence and management services
  MuscleGroupSelection/ — Home screen: muscle group category grid
  Picker/             — All picker sheets (exercise, weight, seat, icon, name, active-set edit)
  Schedule/           — Training calendar, streaks, week summary, day details (implementation: `Packages/FitnessSchedule` SPM target)
  Training/           — Training session screen
  Workouts/           — Workout CRUD, workout list

Packages/
  FitnessProfile/     — SPM library for profile feature (`BMIService`, `ProfileViewModel`, `ProfileStore`). Depends on `FitnessUI`. Tests: `BMIServiceTests` (stubbed API), `ProfileViewModelTests`.
  FitnessTraining/    — SPM library mirroring training flow types from the app (`TrainingCoordinator`, active set VM/cache/timer, bottom action bar, session/picker components). Sources: `Packages/FitnessTraining/Sources/FitnessTraining/`.
  FitnessTestSupport/ — Shared test utilities: `makeExercise` factory, `MockAnalyticsStorage`, `StubAnalyticsStorage`, `MockExerciseStorage`, `MockWorkoutStorage`, `MockTotalAnalyticsStorage`, `waitUntil` with timeout assertion. Depends on `FitnessCore` + `Testing`.

Tests/
  FitnessAppUITests/      — UI tests (XCUITest)
  Packages/*/Tests/       — Package-level unit tests per SPM module
    FitnessAnalyticsTests/  — AnalyticsViewModelTests, TotalAnalyticsViewModelTests
    FitnessStorageTests/    — WorkoutStorageServiceTests, ExerciseStorageServiceTests, AnalyticsStorageServiceTests, ExerciseAndAnalyticsStorageTests, DataMigrationServiceTests
    FitnessScheduleTests/   — ScheduleViewModelTests
```

## Domain Models

Located in `Core/Model/`.

| Model | File | Key Properties |
|-------|------|----------------|
| `AnalyticsEntry` | `AnalyticsEntry.swift` | `id`, `exerciseId`, `date`, `setProgress` |
| `Exercise` | `Exercise.swift` | `id`, `name`, `weight`, `reps`, `sets`, `seatSetting`, `noSeats`, `isCompleted`, `iconName`, `category`, `goal`. **Note:** `Equatable` compares only `id`. Use `isContentEqual(to:)` for value-level comparison. |
| `Workout` | `Workout.swift` | `id`, `name`, `createdDate`, `lastModified`, `selectedCategories` |
| `MuscleCategoryGroup` | `MuscleCategoryGroup.swift` | Enum: `arms`, `chest`, `back`, `legs`, `abs`. `displayName` is provided by `FitnessUI` extension (`MuscleCategoryGroup+UI.swift`), not in FitnessCore. |
| `SetProgress` | `SetProgress.swift` | `id`, `status` (enum: `notStarted`, `inProgress`, `completedDone/Less/More`), `currentReps`, `weight`. Conforms to `Identifiable`. |
| `WeightPhase` | `WeightPhase.swift` | `id`, `weight`, `sessionCount`, `durationDays`, `startSetsReps`, `startDate`, `endSetsReps`, `endDate`, `hasImproved`, `maxReps` |
| `SetEditingMode` | `SetEditingMode.swift` | Enum: `less`, `more`, `edit` |
| `ExerciseEditMode` | `ExerciseEditMode.swift` (SPM: `Packages/FitnessCore`) | Enum: `full`, `name`, `weight`, `seat` — shared with `FitnessTraining` |

## Services

All services are registered in a [hmlongco/Factory](https://github.com/hmlongco/Factory) DI container. Access via `@Injected(\.keyPath)` or `Container.shared.keyPath()`. No more `static let shared` singletons — use the container instead.

**Container registrations:**
- `Packages/FitnessStorage/Sources/FitnessStorage/StorageContainer.swift` — `workoutStorage`, `exerciseStorage`, `analyticsStorage`, `exerciseManagement`, `totalAnalyticsStorage`, `deleteWorkoutUseCase`, `duplicateWorkoutUseCase`
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/AnalyticsContainer.swift` — `saveAnalyticsUseCase`, `deleteAnalyticsSetUseCase`, `saveOrReplaceAnalyticsUseCase`
- `Packages/FitnessExercise/Sources/FitnessExercise/ExerciseContainer.swift` — `resetAllExercisesUseCase`
- `Packages/FitnessTraining/Sources/FitnessTraining/TrainingContainer.swift` — `sessionTrainingCache`, `trainingCoordinatorCache`, `startTrainingUseCase`, `completeSetUseCase`, `finishExerciseUseCase`, `cancelTrainingUseCase`, `resetExerciseUseCase`

| Service | File | Container Key | Scope | Purpose |
|---------|------|---------------|-------|---------|
| `WorkoutStorageService` | `Packages/FitnessStorage/.../WorkoutStorageService.swift` | `\.workoutStorage` | singleton | Workout CRUD, current workout selection, default workout. SwiftData-backed. Errors logged via `os.Logger`. Conforms to `WorkoutStoring` protocol (`FitnessCore`). |
| `ExerciseStorageService` | `Packages/FitnessStorage/.../ExerciseStorageService.swift` | `\.exerciseStorage` | singleton | Exercise persistence per workout/category. SwiftData-backed. Errors logged via `os.Logger`. Conforms to `ExerciseStoring` protocol (`FitnessCore`). |
| `ExerciseManagementService` | `Packages/FitnessStorage/.../ExerciseManagementService.swift` | `\.exerciseManagement` | singleton | Exercise business logic (add, remove, reorder). Conforms to `ExerciseManaging` protocol (`FitnessCore`). |
| `AnalyticsStorageService` | `Packages/FitnessStorage/.../AnalyticsStorageService.swift` | `\.analyticsStorage` | singleton | Per-exercise analytics entry persistence. SwiftData-backed. Errors logged via `os.Logger`. Conforms to `AnalyticsStoring` protocol (`FitnessCore`). |
| `TotalAnalyticsStorageService` | `Packages/FitnessStorage/.../TotalAnalyticsStorageService.swift` | `\.totalAnalyticsStorage` | singleton | Cross-exercise analytics loading, workout-scoped. Conforms to `TotalAnalyticsStoring` protocol (`FitnessCore`). |
| `DataMigrationService` | `Packages/FitnessStorage/.../DataMigrationService.swift` | — | static | One-time migration from JSON/UserDefaults to SwiftData. Runs on first launch after update. |
| `ModelContainer` | via `StorageContainer.swift` | `\.modelContainer` | singleton | Shared SwiftData container for all `@Model` types (`WorkoutModel`, `ExerciseModel`, `AnalyticsEntryModel`, `SetProgressModel`). |
| `BMIService` | `Packages/FitnessProfile/Sources/FitnessProfile/BMIService.swift` | — | per-use | Fetches BMI from external API (bmicalculatorapi.vercel.app), parses category (Underweight/Normal/Overweight/Obesity), with BMI-value fallback for unknown categories |
| `TimerService` | `Packages/FitnessTraining/.../TimerService.swift` | — | per-use | Rest timer during active sets |
| `SessionTrainingCache` | `Packages/FitnessTraining/.../SessionTrainingCache.swift` | `\.sessionTrainingCache` | singleton | Per-category `ActiveSetViewModel` cache. Conforms to `SessionTrainingCaching` protocol. Use `viewModel(for:)` for typed access. |
| `TrainingCoordinatorCache` | `Packages/FitnessTraining/.../TrainingCoordinatorCache.swift` | `\.trainingCoordinatorCache` | singleton | Per-category `TrainingCoordinator` cache. Conforms to `TrainingCoordinatorCaching` protocol. Ensures all views share the same coordinator per `MuscleCategoryGroup`. Use `coordinator(for:)` for category-scoped access, `findCoordinator(for:)` to locate the coordinator for a specific exercise. |

## Use Cases

Single-responsibility types with one `execute(...)` method. ViewModels call Use Cases; Views never call services directly. Located in `UseCases/` folders within the relevant package.

| Use Case | File | Container Key | Purpose |
|----------|------|---------------|---------|
| `DeleteWorkoutUseCase` | `Packages/FitnessStorage/.../UseCases/DeleteWorkoutUseCase.swift` | `\.deleteWorkoutUseCase` | Delete workout, handle current-workout fallback, clean up exercise files |
| `DuplicateWorkoutUseCase` | `Packages/FitnessStorage/.../UseCases/DuplicateWorkoutUseCase.swift` | `\.duplicateWorkoutUseCase` | Copy workout with all exercises per category |
| `SaveAnalyticsUseCase` | `Packages/FitnessAnalytics/.../UseCases/SaveAnalyticsUseCase.swift` | `\.saveAnalyticsUseCase` | Create analytics entry and append to exercise history |
| `DeleteAnalyticsSetUseCase` | `Packages/FitnessAnalytics/.../UseCases/DeleteAnalyticsSetUseCase.swift` | `\.deleteAnalyticsSetUseCase` | Remove set from entry, remove entry if empty, update exercise completion |
| `SaveOrReplaceAnalyticsUseCase` | `Packages/FitnessAnalytics/.../UseCases/SaveOrReplaceAnalyticsUseCase.swift` | `\.saveOrReplaceAnalyticsUseCase` | Find existing entry for date and replace, or append new |
| `ResetAllExercisesUseCase` | `Packages/FitnessExercise/.../UseCases/ResetAllExercisesUseCase.swift` | `\.resetAllExercisesUseCase` | Cancel all active sets, reset exercises across categories |
| `StartTrainingUseCase` | `Packages/FitnessTraining/.../UseCases/StartTrainingUseCase.swift` | `\.startTrainingUseCase` | Determine resume vs fresh start, initialize active set |
| `CompleteSetUseCase` | `Packages/FitnessTraining/.../UseCases/CompleteSetUseCase.swift` | `\.completeSetUseCase` | Validate and complete current set, start next if not last |
| `FinishExerciseUseCase` | `Packages/FitnessTraining/.../UseCases/FinishExerciseUseCase.swift` | `\.finishExerciseUseCase` | Stop timer, save analytics, mark exercise completed, reset state |
| `CancelTrainingUseCase` | `Packages/FitnessTraining/.../UseCases/CancelTrainingUseCase.swift` | `\.cancelTrainingUseCase` | Cancel active set and clear training state |
| `ResetExerciseUseCase` | `Packages/FitnessTraining/.../UseCases/ResetExerciseUseCase.swift` | `\.resetExerciseUseCase` | Stop timer, trigger exercise reset callback, clear progress |

## Shared Components

Located in `Shared/`.

| Component | File | Purpose |
|-----------|------|---------|
| `WorkoutFormSheet` | `View/WorkoutFormSheet.swift` | Full-screen form sheet with title, save, dismiss |
| `WorkoutDropdownView` | `Packages/FitnessUI/Sources/FitnessUI/WorkoutDropdownView.swift` | Workout name dropdown button (reads from WorkoutStorageService) |
| `WorkoutPickerView` | `Packages/FitnessUI/Sources/FitnessUI/WorkoutPickerView.swift` | Wheel picker for workout selection with optional `onSelect` (defaults to `setCurrentWorkout` on injected storage) |
| `MiniActionMenuView` | `View/MiniActionMenuView.swift` | Small context menu with icon + title rows |
| `CapsuleToggleStyle` | `View/CapsuleToggleStyle.swift` | Reusable toggle style with on/off colors |
| `TrainingSessionComponent` | `View/TrainingSessionComponent.swift` (SPM copy: `Packages/FitnessTraining/.../TrainingSessionComponent.swift`) | Training session UI driven by TrainingCoordinator |
| `TrainingPickerComponent` | `View/TrainingPickerComponent.swift` (SPM copy: `Packages/FitnessTraining/.../TrainingPickerComponent.swift`) | Training picker UI using TrainingCoordinator |
| `TrainingIDs` | `Packages/FitnessUI/Sources/FitnessUI/TrainingIDs.swift` | Accessibility identifiers for training FABs and set rows |
| `UIOverlayState` | `Packages/FitnessUI/Sources/FitnessUI/UIOverlayState.swift` | Global overlay/menu visibility (also still in app `Shared/State/UIOverlayState.swift` until unified) |
| `ActiveSetEditPickerView` | `Packages/FitnessUI/Sources/FitnessUI/ActiveSetEditPickerView.swift` | Reps/weight wheel sheet for active-set edits |
| `OverlaySheetContainer` | `Packages/FitnessUI/Sources/FitnessUI/ExercisePickerSheetChrome.swift` | Reusable overlay sheet with backdrop, grabber, swipe-dismiss, appear animation. Separates content (scrollable), actions (fixed bottom), and overlay (e.g. numpad). All picker sheets use this. |
| `ExercisePickerActionButtons` / `exercisePickerSheet` | `Packages/FitnessUI/Sources/FitnessUI/ExercisePickerSheetChrome.swift` | Shared picker sheet chrome (inner styling + action buttons) |
| `MetricChipView` | `Features/Exercise/ExerciseCard/MetricChipView.swift` | Generic chip container with background/stroke |
| `WeightPhaseTileView` | `Features/Exercise/ExerciseCard/WeightPhaseTileView.swift` | Weight/reps phase tile for analytics display |
| `CardBackground` | `Features/Exercise/ExerciseCard/CardBackground.swift` | Card wrapper with `Style` enum (`.glass`, `.gradient(Color)`) |
| `SetTileView` | `Features/Exercise/ExerciseCard/SetTileView.swift` | Completed set display tile (weight/reps) |
| `SetRowChipStyle` | `Features/Exercise/ActiveSet/SimpleActiveSetView.swift` | ViewModifier for set row chips — use `.setRowChipStyle(minWidth:)` |


## Utilities

Located in `Shared/Utilities/`.

| Utility | File | Usage |
|---------|------|-------|
| `WeightFormatter` | `WeightFormatter.swift` | `displayWeight(_:)` — always use for weight display |
| `AnalyticsDateHelper` | `AnalyticsDateHelper.swift` | Month names, unique days, days-in-month for analytics |
| `DateFormatterUtility` | `DateFormatterUtility.swift` | Shared DateFormatter instances (`germanMedium`, `germanMonthYear`, etc.) |
| `WeightOptionsGenerator` | `WeightOptionsGenerator.swift` | Generate weight option arrays for pickers |
| `L10n` | `L10n.swift` | Static user-facing strings for exercises, muscles, analytics, etc. |
| `SafeAreaInsetsKey` | `SafeAreaInsetsKey.swift` | `@Environment(\.safeAreaInsets)` — use instead of deprecated `UIApplication.shared.windows` |
| `TimeFormatter` | `TimeFormatter.swift` | `Int.formattedAsTimer` — formats seconds as `MM:SS` |

## Extensions

| Extension | File | Purpose |
|-----------|------|---------|
| `View+Toolbar` | `Extensions/View+Toolbar.swift` | `.standardToolbar(title:)` modifier for consistent screen headers |
| `Color+Extension` | `Design/Color+Extension.swift` | `Color(hex:)` initializer |
| `SwipeBackGestureModifier` | `Shared/Extensions/SwipeBackGestureModifier.swift` | `.enableSwipeBack()` modifier |

## State & Navigation

| Type | File | Purpose |
|------|------|---------|
| `AppRouter` | `Packages/FitnessExercise/Sources/FitnessExercise/AppRouter.swift` | Centralized navigation state (`NavigationPath` + `currentScene`), injected via `.environmentObject()` |
| `AppCurrentScene` | `Packages/FitnessExercise/Sources/FitnessExercise/AppRouter.swift` | Enum: `workouts`, `home`, `profile`, `category`, `training`, `schedule`, `analytics` — derived automatically by `AppRouter` |
| `NavigationDestination` | `Packages/FitnessExercise/Sources/FitnessExercise/NavigationDestination.swift` | Enum with all navigation cases, shared across app and packages |
| `AppLaunchStrategy` | `Shared/Navigation/AppLaunchStrategy.swift` | Protocol for app launch configuration; `ProductionLaunchStrategy` (default) and `UITestLaunchStrategy` (`Shared/Navigation/UITestLaunchStrategy.swift`, `#if UITESTING`) |
| `TrainingCoordinator` | `Packages/FitnessTraining/.../TrainingCoordinator.swift` | Thin state-holder + orchestrator; delegates business logic to Use Cases |
| `UIOverlayState` | `Shared/State/UIOverlayState.swift` | Global overlay/menu visibility state |

## Navigation

All navigation destinations are in `FitnessAppApp.swift`:

```swift
enum NavigationDestination: Hashable {
    case home              // -> MuscleCategorySelectionView
    case profile           // -> ProfileView
    case totalAnalytics    // -> TotalAnalyticsView
    case schedule          // -> ScheduleView
    case muscleCategory(MuscleCategoryGroup) // -> MuscleCategoryView
    case training(Exercise, MuscleCategoryGroup) // -> TrainingView
}
```

Navigation is managed by `AppRouter` (injected as `@EnvironmentObject`). Use `router.navigate(to:)` to push, `router.pop()` to go back, `router.popToRoot()` to reset, and `router.replaceAll(with:)` for tab switches or deep links. `AppRouter` automatically derives `currentScene: AppCurrentScene` from the navigation stack — do **not** set the current scene manually. Do **not** manipulate `NavigationPath` directly in views.

## AppStyle Tokens

All tokens in `Shared/Design/AppStyle.swift`. When no token exists for a value, add one before using.

### Padding

`horizontal` (18), `screenHorizontal` (15), `card` (16), `titleTop` (8), `titleBottom` (17), `activeCardIconOverflow` (20), `sectionSpacing` (18)

### Layout

`cardHorizontalPadding` (16), `chipHeight` (32), `activeCardContentHeight` (80), `activeCardMaxWidth` (400), `categoryIconSize` (50), `checkmarkSize` (36), `playButtonSize` (36), `playIconSize` (16), `completedBarWidth` (8), `setRowBadgeSize` (26), `analyticsImageSize` (60), `seatIconSize` (22), `analyticsEntryIconSize` (24), `separatorHeight` (28), `doneButtonWidth` (80), `doneButtonHeight` (28), `profileCardMinHeight` (100), `profileAvatarSize` (80), `numberPadKeySize` (60), `numberPadSpacing` (12), `scrollWheelItemHeight` (60), `scrollWheelVisibleItems` (5), `scrollWheelSnapTolerance` (18), `sheetContentBottomPad` (23)

### CornerRadius

`card` (16), `bottomBarButton` (12), `editPickerViewButton` (12), `defaultButton` (12), `sheet` (22), `tile` (10), `timerCard` (12), `numberPadKey` (12), `pill` (20)

### Font

| Token | Size | Weight |
|-------|------|--------|
| `navigationHeadline` | 28 | bold |
| `cardHeadline` | 18 | bold |
| `regularChip` | 16 | semibold |
| `largeChip` | 24 | semibold |
| `defaultFont` | 12 | semibold |
| `bottomBarButtons` | 16 | semibold |
| `analyticsExerciseTitle` | 20 | semibold |
| `analyticsExerciseData` | 16 | semibold |
| `analyticsHeadline` | 22 | bold |
| `analyticsBigNumber` | 26 | bold |
| `analyticsAxis` | 9 | medium |
| `categorySelectionNameFont` | 20 | semibold |
| `categoryTileTitle` | 22 | bold |
| `categoryTileCount` | 16 | black |
| `categoryTileBadge` | 14 | heavy |
| `categoryTileProgress` | 12 | heavy |
| `tileLabel` | 14 | semibold |
| `tileValue` | 16 | medium |
| `sectionTitle` | 18 | medium |
| `sectionHeadline` | 18 | semibold |
| `numberPadKey` | 24 | medium |
| `numberPadDisplay` | 32 | regular |
| `numberPadSymbol` | 24 | regular |
| `chartLabel` | 10 | regular |
| `chartAxisSmall` | 10 | medium |
| `pickerAction` | 14 | regular |
| `cardBoldTitle` | 20 | bold |
| `cardSmallBold` | 12 | bold |
| `cardSmallLabel` | 10 | semibold |
| `cardTinyLabel` | 9 | regular |
| `cardValueBold` | 16 | bold |
| `cardSmallMedium` | 11 | bold |
| `metricLabel` | 11 | medium |
| `iconSymbol` | 20 | semibold |
| `calendarHeader` | 16 | semibold |
| `calendarSubheader` | 12 | medium |
| `calendarDay` | 14 | regular |
| `calendarDayBold` | 14 | bold |
| `dayChipLabel` | 10 | semibold |
| `dayChipNumber` | 13 | regular |
| `dayChipNumberBold` | 13 | bold |
| `detailCategory` | 15 | bold |
| `detailExercise` | 14 | medium |
| `detailBadge` | 14 | bold |
| `detailCaption` | 12 | medium |
| `streakLabel` | 11 | medium |
| `streakValue` | 16 | bold |
| `profileGreeting` | 26 | bold |
| `profileSubtitle` | 15 | medium |
| `profileCardTitle` | 13 | medium |
| `profileCardValue` | 28 | bold |
| `profileCardUnit` | 14 | semibold |
| `profileBMICategory` | 14 | semibold |
| `profileInputLabel` | 14 | semibold |
| `sheetTitle` | 22 | bold |
| `sheetSectionLabel` | 17 | semibold |
| `sheetCaption` | 12 | regular |
| `numberPadSelectedValue` | 48 | bold |

### Color

`backgroundColor`, `primaryButton`, `exerciseCardBackground`, `chipsBackground`, `white`, `black`, `yellow`, `gray`, `grayDark`, `greenBlack`, `greenDark`, `green`, `greenLight`, `greenGlow`, `sheetBackground`, `sheetInputBackground`, `metricChipBackground`, `progressTrack`, `numberPadGray`, `trainingAccent`, `inProgressGold`, `profileCardBackground`, `bmiUnderweight`, `bmiNormal`, `bmiOverweight`, `bmiObese`

### Opacity

`overlayBackdrop` (0.55), `subtleBackground` (0.06), `subtleStroke` (0.15), `grabberHandle` (0.35), `disabledElement` (0.3), `fadedOverlay` (0.4), `numberPadInactive` (0.5), `numberPadFade` (0.2)

### Shadow

`cardColor` (black 0.2), `cardRadius` (5), `cardY` (2)

### DeviceLayout

Centralized responsive layout tokens replacing scattered `UIScreen.main.bounds.width` breakpoints.

| Token | compact (<=375) | regular (376–400) | large (401–429) | extraLarge (>=430) |
|-------|-----------------|-------------------|-----------------|---------------------|
| `cardSpacing` | 6 | 8 | 8 | 8 |
| `cardPadding` | 4 | 6 | 8 | 8 |
| `analyticsButtonWidth` | 62 | 65 | 70 | 80 |
| `chipWidthVertical` | 63 | 63 | 63 | 71 |
| `iconContainerWidth` | 72 | 72 | 72 | 82 |
| `exerciseIconSize` | 98 | 98 | 98 | 108 |
| `analyticsToIconSpacing` | 4 | 6 | 8 | 12 |
| `setRowWeightMinWidth` | 50 | 60 | 60 | 60 |
| `setRowRepsMinWidth` | 110 | 120 | 120 | 120 |
| `trainingSessionSpacing` | 8 | 10 | 12 | 16 |
| `timerFontSize` | 15 | 16 | 18 | 20 |

### Animation

`keyboardSpring` (response 0.32, damping 0.88), `snapSpring` (response 0.3, damping 0.8)

### Blur

`iconGlow` (12)

## Domain Models — State Structs

`ActiveSetViewModel` uses internal state structs for organization:

| Struct | Properties |
|--------|------------|
| `SetTrackingState` | `currentExercise`, `setProgress`, `currentSet`, `activeSetIndex`, `isSetInProgress`, `isLastSetCompleted`, `category`, `originalCategory` |
| `SetEditingState` | `isEditing`, `repsInput`, `weightInput`, `editMode`, `pendingEditIndex`, `didEditCompleteSet`, `didJustEditSet` |
| `QuickDoneState` | `isActive`, `allCompleted` |

These are accessed through bridged computed properties on `ActiveSetViewModel` for backward compatibility.

## Live Activity

Located in `Shared/LiveActivity/`.

| File | Purpose |
|------|---------|
| `TrainingActivityAttributes.swift` | Live Activity data model |
| `TrainingActivityManager.swift` | Start/update/end Live Activities |
| `TrainingLiveActions.swift` | Live Activity action handling |
| `Widget/TrainingActivityWidget.swift` | Widget UI |
| `Widget/Intents/` | `DoneIntent`, `LessIntent`, `MoreIntent` |
