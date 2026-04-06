# FitnessApp Architecture

## Feature Map

```
Features/
  Analytics/          — Exercise analytics, charts, total analytics overview
  BottomBar/          — Bottom navigation bar, bottom action bar
    Profile/          — User profile screen
  Exercise/
    ActiceSet/        — Active set tracking during training
      Timer/Service/  — Timer service for rest intervals
    ExerciseCard/     — Card UI for exercises (idle, active, inactive states)
    MuscleCategory/   — Muscle category detail screen with exercises
    Storage/          — Exercise persistence and management services
  MuscleGroupSelection/ — Home screen: muscle group category grid
  Navigation/         — Swipe-back gesture modifier
  Picker/             — All picker sheets (exercise, weight, seat, icon, name, active-set edit)
  Schedule/           — Training calendar, streaks, week summary, day details
  Training/           — Training session screen
  Workouts/           — Workout CRUD, workout list, workout storage
```

## Domain Models

Located in `Core/Model/`.

| Model | File | Key Properties |
|-------|------|----------------|
| `Exercise` | `Exercise.swift` | `id`, `name`, `weight`, `reps`, `sets`, `seatSetting`, `noSeats`, `isCompleted`, `iconName`, `category`, `goal` |
| `Workout` | `Workout.swift` | `id`, `name`, `createdDate`, `lastModified`, `exerciseData`, `selectedCategories` |
| `MuscleCategoryGroup` | `MuscleCategoryGroup.swift` | Enum: `arms`, `chest`, `back`, `legs`, `abs` |
| `SetProgress` | `SetProgress.swift` | `status` (enum: `notStarted`, `inProgress`, `completedDone/Less/More`), `currentReps`, `weight` |
| `WeightPhase` | `WeightPhase.swift` | `id`, `weight`, `sessionCount`, `durationDays`, `startSetsReps`, `startDate`, `endSetsReps`, `endDate`, `hasImproved`, `maxReps` |
| `SetEditingMode` | `SetEditingMode.swift` | Enum: `less`, `more`, `edit` |

## Services

| Service | File | Singleton | Purpose |
|---------|------|-----------|---------|
| `WorkoutStorageService` | `Features/Workouts/WorkoutStorageService.swift` | `.shared` | Workout CRUD, current workout selection, default workout |
| `ExerciseStorageService` | `Features/Exercise/Storage/ExerciseStorageService.swift` | No | Exercise persistence per workout/category |
| `ExerciseManagementService` | `Features/Exercise/Storage/ExerciseManagementService.swift` | No | Exercise business logic (add, remove, reorder) |
| `AnalyticsStorageService` | `Features/Analytics/AnalyticsStorageService.swift` | No | Per-exercise analytics entry persistence |
| `TotalAnalyticsStorageService` | `Features/Analytics/TotalAnalyticsStorageService.swift` | No | Cross-exercise analytics loading, workout-scoped |
| `TimerService` | `Features/Exercise/ActiceSet/Timer/Service/TimerService.swift` | No | Rest timer during active sets |

## Shared Components

Located in `Shared/`.

| Component | File | Purpose |
|-----------|------|---------|
| `MetricChipView` | `View/MetricChipView.swift` | Fixed-height chip container with background/stroke |
| `WorkoutFormSheet` | `View/WorkoutFormSheet.swift` | Full-screen form sheet with title, save, dismiss |
| `AnalyticsDetailSection` | `View/AnalyticsDetailSection.swift` | Generic collapsible section with header/content |
| `WorkoutDropdownView` | `View/WorkoutDropdownView.swift` | Workout name dropdown button (reads from WorkoutStorageService) |
| `WorkoutPickerView` | `View/WorkoutPickerView.swift` | Wheel picker for workout selection with onSelect callback |
| `CalendarDialogView` | `View/CalendarDialogView.swift` | Date picker dialog with highlighted dates |
| `MiniActionMenuView` | `View/MiniActionMenuView.swift` | Small context menu with icon + title rows |
| `CapsuleToggleStyle` | `View/CapsuleToggleStyle.swift` | Reusable toggle style with on/off colors |
| `TrainingSessionComponent` | `Components/TrainingSessionComponent.swift` | Training session UI driven by TrainingCoordinator |
| `TrainingPickerComponent` | `Components/TrainingPickerComponent.swift` | Training picker UI using TrainingCoordinator |
| `AppChip` | `Design/AppChip.swift` | Styled chip with size variants |
| `ChipIcon` | `Design/ChipIcon.swift` | Icon rendering for chips |
| `LiquidGlass` | `Design/LiquidGlass.swift` | Glass-effect modifier |

## Utilities

Located in `Shared/Utilities/`.

| Utility | File | Usage |
|---------|------|-------|
| `WeightFormatter` | `WeightFormatter.swift` | `displayWeight(_:)` — always use for weight display |
| `AnalyticsDateHelper` | `AnalyticsDateHelper.swift` | Month names, unique days, days-in-month for analytics |
| `DateFormatterUtility` | `DateFormatterUtility.swift` | Shared DateFormatter instances (`germanMedium`, `germanMonthYear`, etc.) |
| `WeightOptionsGenerator` | `WeightOptionsGenerator.swift` | Generate weight option arrays for pickers |

## Extensions

| Extension | File | Purpose |
|-----------|------|---------|
| `View+Toolbar` | `Extensions/View+Toolbar.swift` | `.standardToolbar(title:)` modifier for consistent screen headers |
| `Color+Extension` | `Design/Color+Extension.swift` | `Color(hex:)` initializer |
| `SwipeBackGestureModifier` | `Features/Navigation/SwipeBackGestureModifier.swift` | `.enableSwipeBack()` modifier |

## Coordinators & State

| Type | File | Purpose |
|------|------|---------|
| `TrainingCoordinator` | `Shared/Coordinators/TrainingCoordinator.swift` | Orchestrates training session flow |
| `UIOverlayState` | `Shared/UIOverlayState.swift` | Global overlay/menu visibility state |
| `AppCurrentScene` | `Shared/UIOverlayState.swift` | Enum: `workouts`, `home`, `profile`, `category`, `training`, `schedule` |

## Navigation

All navigation destinations are in `FitnessAppApp.swift`:

```swift
enum NavigationDestination: Hashable {
    case workouts
    case home              // -> MuscleCategorySelectionView
    case profile           // -> ProfileView
    case totalAnalytics    // -> TotalAnalyticsView
    case schedule          // -> ScheduleView
    case muscleCategory(MuscleCategoryGroup) // -> MuscleCategoryView
    case training(Exercise, MuscleCategoryGroup) // -> TrainingView
}
```

Navigate via `navigationPath.append(NavigationDestination.<case>)`.

## AppStyle Tokens

All tokens in `Shared/Design/AppStyle.swift`. When no token exists for a value, add one before using.

### Padding

`horizontal` (18), `screenHorizontal` (15), `card` (16), `titleTop` (8), `titleBottom` (17), `activeCardIconOverflow` (20)

### Layout

`cardHorizontalPadding` (16)

### CornerRadius

`card` (16), `bottomBarButton` (12), `editPickerViewButton` (12), `defaultButton` (12), `sheet` (22)

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
| `categorySelectionNameFont` | 20 | semibold |
| `tileLabel` | 14 | semibold |
| `tileValue` | 16 | medium |
| `sectionTitle` | 18 | medium |
| `numberPadKey` | 24 | medium |
| `chartLabel` | 10 | regular |
| `pickerAction` | 14 | regular |
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

### Color

`backgroundColor`, `primaryButton`, `exerciseCardBackground`, `chipsBackground`, `white`, `black`, `yellow`, `gray`, `grayDark`, `greenBlack`, `greenDark`, `green`, `greenLight`, `greenGlow`, `sheetBackground`, `sheetInputBackground`, `metricChipBackground`, `progressTrack`, `numberPadGray`, `trainingAccent`

### Opacity

`overlayBackdrop` (0.55), `subtleBackground` (0.06), `subtleStroke` (0.15), `grabberHandle` (0.35)

## Live Activity

Located in `Shared/LiveActivity/`.

| File | Purpose |
|------|---------|
| `TrainingActivityAttributes.swift` | Live Activity data model |
| `TrainingActivityManager.swift` | Start/update/end Live Activities |
| `TrainingLiveActions.swift` | Live Activity action handling |
| `Widget/TrainingActivityWidget.swift` | Widget UI |
| `Widget/Intents/` | `DoneIntent`, `LessIntent`, `MoreIntent` |
