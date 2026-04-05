# FitnessApp Architecture Reference

## Domain Models (`Core/Model/`)

**Exercise** — a single exercise within a workout category
- `id: UUID`, `name: String`, `weight: Double`, `reps: Int`, `sets: Int`
- `seatSetting: String?`, `noSeats: Bool`, `isCompleted: Bool`
- `iconName: String`, `category: MuscleCategoryGroup`, `goal: Double?`
- Computed: `hasWeight`, `displayIconName`, `iconAlignment`

**Workout** — a named collection of exercises grouped by muscle category
- `id: UUID`, `name: String`, `createdDate: Date`, `lastModified: Date`
- `exerciseData: [String: Any]`, `selectedCategories: Set<MuscleCategoryGroup>`
- Methods: `updateLastModified()`, `copy(withName:)`

**MuscleCategoryGroup** — enum: `.arms`, `.chest`, `.back`, `.legs`, `.abs`
- Properties: `displayName`, `availableIcons`, `defaultIconName`

**SetProgress** — tracks progress for a single set
- `status: SetStatus`, `currentReps: Int`, `weight: Double`
- SetStatus: `.notStarted`, `.inProgress`, `.completedDone`, `.completedLess`, `.completedMore`

**SetEditingMode** — enum: `.less`, `.more`, `.edit`

**WeightPhase** — struct tracking weight progression over time
- `weight`, `sessionCount`, `durationDays`, `startDate`, `endDate`, `hasImproved`

**AnalyticsEntry** — a single training session record for one exercise
- `id: UUID`, `exerciseId: UUID`, `date: Date`, `setProgress: [SetProgress]`
- Codable, persisted as JSON via AnalyticsStorageService

**DailyProgression** — typealias `(date: Date, value: Double)` in AnalyticsViewModel
- Used by `ProgressChartCalculator` for chart rendering

## Services

**WorkoutStorageService** (`Shared singleton`) — `Features/Workouts/WorkoutStorageService.swift`
- `.shared`, `@Published workouts`, `@Published currentWorkout`, `@Published defaultWorkout`
- `createWorkout(name:selectedCategories:)`, `deleteWorkout(_:)`, `updateWorkout(_:)`
- `setCurrentWorkout(_:)`, `setAsDefaultWorkout(_:)`, `renameWorkout(_:newName:)`

**ExerciseStorageService** — `Features/Exercise/Storage/ExerciseStorageService.swift`
- `load(for group:) -> [Exercise]`, `save(_:for:)`
- `loadForWorkout(workoutId:category:)`, `saveForWorkout(_:workoutId:category:)`

**ExerciseManagementService** (`ObservableObject`) — `Features/Exercise/Storage/ExerciseManagementService.swift`
- `addExercise(_:category:atTop:)`, `updateExercise(_:category:)`
- `completeExercise(_:category:setProgress:)`, `resetExercise(_:category:)`
- `getExercises(for:)`, `getExerciseCount(for:)`, `getAllExerciseCounts(for:)`

**AnalyticsStorageService** — `Features/Analytics/AnalyticsStorageService.swift`
- `save(_ entries:for exerciseId:)`, `load(for exerciseId:) -> [AnalyticsEntry]`

**TotalAnalyticsStorageService** — `Features/Analytics/TotalAnalyticsStorageService.swift`
- `loadAllAnalytics()`, `loadAllAnalytics(for workoutId:)`, `loadAllAnalytics(for date:)`
- `getAllExercisesWithAnalytics()`, `getAllExercisesWithAnalytics(for workoutId:)`

**TimerService** — `Features/Exercise/ActiceSet/Timer/Service/TimerService.swift`
- `@Published timerSeconds: Int`
- `startTimer()`, `resetAndStartTimer()`, `stopTimer()`

**ProgressChartCalculator** — `Features/Analytics/ProgressChartCalculator.swift`
- `calculateDynamicMilestones(milestones: [DailyProgression], geometry:) -> [ChartPoint]`
- `ChartPoint`: weight, date, xPosition, yPosition, isCurrentWeight
- Used by AnalyticsView for weight/reps progression charts

## Coordinators & State

**TrainingCoordinator** (`ObservableObject`) — `Shared/Coordinators/TrainingCoordinator.swift`
- Orchestrates active training session across views
- `@Published activeSetViewModel`, `@Published currentExercise`, `@Published isTrainingActive`
- `startTraining(for:)`, `completeSet()`, `handleQuickDone()`, `finishExercise()`
- Provides `TrainingCallbacks` struct with closures for start/complete/reset/edit/finish
- Creates `BottomActionBarViewModel` for bottom bar state

**BottomActionBarViewModel** (**struct**, not ObservableObject) — `Features/BottomBar/BottomActionBarViewModel.swift`
- Pure value-type snapshot rebuilt by TrainingCoordinator on each state change
- Key fields: `isSetInProgress`, `currentSet`, `currentExercise`, `exercises`, `isLastSetCompleted`, quick-done/edit flags
- Computed: `shouldShow`, `showStartButton`, `showSetControls`, `showFinishButton`
- Do NOT add @Published or convert to class — this is intentionally a snapshot pattern

**SessionTrainingCache** (`Shared singleton`) — `Features/Exercise/ActiceSet/SessionTrainingCache.swift`
- `.shared`, `activeSetVMs: [MuscleCategoryGroup: ActiveSetViewModel]`
- Preserves ActiveSetViewModel per category across navigation

**UIOverlayState** (`ObservableObject, @EnvironmentObject`) — `Shared/UIOverlayState.swift`
- Controls overlay visibility: `showCategoryMiniMenu`, `showSelectionMiniMenu`, `showWorkoutsMiniMenu`, `showWorkoutDropdown`, `showWorkoutSettingsMenu`, `showTrainingMiniMenu`
- `isEditingSheetVisible`, `isCancellingTraining`
- `currentScene: AppCurrentScene` (`.workouts`, `.home`, `.profile`, `.category`, `.training`)

## Known Architectural Notes

- **ProfileView** uses `@AppStorage` directly, not ProfileViewModel. ProfileViewModel exists but is unused. New Profile features should either adopt the ViewModel or continue with @AppStorage — pick one pattern.
- **Data persistence**: Exercise and analytics data is stored as JSON files via FileManager. Workout data uses UserDefaults. There is no CoreData or SwiftData.
- **Data migration**: Models decoded from JSON have no automatic migration. When adding a new field to a `Codable` model, it **must** be optional (`String?`) or have a default value (`var notes: String = ""`), otherwise decoding existing stored data will crash. Never add a required field without a default.
- **Enum extensions**: When adding a case to an enum (e.g. `MuscleCategoryGroup`, `SetStatus`, `NavigationDestination`), search the entire project for `switch` statements on that enum and handle the new case in every location. Swift compiler warnings catch exhaustive switches, but non-exhaustive patterns (if-case, guard-case) will silently skip the new case.

## Navigation (`FitnessAppApp.swift`)

Root: `NavigationStack` with `WorkoutsScreen` as root view.
Auto-navigates to `.home` if a default workout exists.

```swift
enum NavigationDestination: Hashable {
    case workouts, home, profile, totalAnalytics
    case muscleCategory(MuscleCategoryGroup)
    case training(Exercise, MuscleCategoryGroup)
}
```

Navigate: `navigationPath.append(NavigationDestination.<case>)`

Back navigation: Most screens use `navigationPath.removeLast()`. **Exception**: Training back replaces the entire path with `[.home]` (jumps to category selection, skips intermediate screens). Cancel-training has its own flow via `UIOverlayState.isCancellingTraining`.

## Utilities (`Shared/Utilities/`)

- **WeightFormatter**: `.format(_:)` raw, `.displayWeight(_:)` with "kg", `.parse(_:)`, `.formatGoalForInput(_:)`
- **AnalyticsDateHelper**: `.currentMonthName()`, `.uniqueDays(from:)`, `.daysInCurrentMonth(from:)`
- **WeightOptionsGenerator**: `.exerciseWeightOptions`, `.trainingWeightOptions`
- **DateFormatterUtility**: `.germanMedium`, `.germanShort`, `.germanCompact`, `.germanMonthYear`

## AppStyle Tokens (`Shared/Design/AppStyle.swift`)

**Padding**: `horizontal` (18), `screenHorizontal` (15), `card` (16), `titleTop` (8), `titleBottom` (17)

**CornerRadius**: `card` (16), `bottomBarButton` (12), `editPickerViewButton` (12), `defaultButton` (12), `sheet` (22)

**Font**: `navigationHeadline` (28 bold), `cardHeadline` (18 bold), `regularChip` (16 semi), `largeChip` (24 semi), `defaultFont` (12 semi), `bottomBarButtons` (16 semi), `analyticsExerciseTitle` (20 semi), `analyticsExerciseData` (16 semi), `categorySelectionNameFont` (20 semi), `tileLabel` (14 semi), `tileValue` (16 medium), `sectionTitle` (18 medium), `numberPadKey` (24 medium), `chartLabel` (10 regular), `pickerAction` (14 regular)

**Color**: `backgroundColor`, `primaryButton`, `exerciseCardBackground`, `chipsBackground`, `white`, `black`, `yellow`, `gray`, `grayDark`, `greenBlack`, `greenDark`, `green`, `greenLight`, `greenGlow`, `sheetBackground`, `sheetInputBackground`, `metricChipBackground`, `progressTrack`, `numberPadGray`, `trainingAccent`

**Opacity**: `overlayBackdrop` (0.55), `subtleBackground` (0.06), `subtleStroke` (0.15), `grabberHandle` (0.35)

If a needed token is missing, add it to `AppStyle.swift` with a semantic name before using it.

**Theming note**: Colors are currently defined as static `Color(hex:)` values — there is no Light/Dark mode support. If theming is introduced in the future, colors should migrate to `Color` assets (Asset Catalog) or use `@Environment(\.colorScheme)` with conditional values. Until then, do not use `Color.primary`, `Color.secondary`, or system-adaptive colors — they will conflict with the dark-only design.

## Shared Components (`Shared/View/`, `Shared/Design/`, `Shared/Components/`)

| Component | File | Purpose |
|-----------|------|---------|
| `MetricChipView` | `Shared/View/MetricChipView.swift` | Framed chip with background + stroke (params: width, height, content) |
| `WorkoutFormSheet` | `Shared/View/WorkoutFormSheet.swift` | Full-screen form with drag indicator, header, save (params: title, isSaveDisabled, onSave, isPresented, content) |
| `AnalyticsDetailSection` | `Shared/View/AnalyticsDetailSection.swift` | Expandable analytics card (params: shouldShowIndicator, header, content) |
| `AnalyticsDetailHeader` | `Shared/View/AnalyticsDetailSection.swift` | Back button + centered title/subtitle (params: title, subtitle, onBack) |
| `ExercisePickerSheetModifier` | `Features/Picker/ExercisePickerShared.swift` | Bottom sheet chrome with rounded background (param: isContentVisible) |
| `ExercisePickerActionButtons` | `Features/Picker/ExercisePickerShared.swift` | Cancel/Save row (params: saveDisabled, onCancel, onSave) |
| `ExerciseWheelPickerRow` | `Features/Picker/ExercisePickerShared.swift` | Sets/Reps/Weight wheel pickers (params: sets, reps, weight bindings, ranges, weightOptions, showWeight) |
| `ExercisePickerInputField` | `Features/Picker/ExercisePickerShared.swift` | Styled text input (params: prompt, text binding) |
| `AppChip` | `Shared/Design/AppChip.swift` | Chip label with size variants |
| `LiquidGlassBackground` | `Shared/Design/LiquidGlass.swift` | Material glass effect |
| `TrainingSessionComponent` | `Shared/Components/TrainingSessionComponent.swift` | Training session UI block |
| `TrainingPickerComponent` | `Shared/Components/TrainingPickerComponent.swift` | Picker within training flow |

## Feature Map

```
Features/
├── Analytics/          — Charts, Calendar, NumberPad, AnalyticsView, TotalAnalyticsView
├── BottomBar/          — BottomMenuBarView, BottomActionBarView, Profile/
├── Exercise/
│   ├── ActiceSet/      — SimpleActiveSetView, ActiveSetViewModel, SessionTrainingCache, Timer/
│   ├── ExerciseCard/   — ActiveCardView, IdleActiveCardView, InactiveCardView, CardBackground
│   ├── MuscleCategory/ — MuscleCategoryView, MuscleCategoryViewModel, ExerciseFormViewModel
│   └── Storage/        — ExerciseStorageService, ExerciseManagementService
├── MuscleGroupSelection/ — MuscleCategorySelectionView (home screen)
├── Navigation/         — SwipeBackGestureModifier
├── Picker/             — Exercise/Weight/Seat/Name/Icon pickers, shared picker components
├── Training/           — TrainingView (dedicated training screen)
└── Workouts/           — WorkoutsScreen, Create/Rename, WorkoutStorageService
```

## Where to Place New Code

| What you are building | Place it in |
|---|---|
| New screen/feature | `Features/<FeatureName>/` (View + ViewModel) |
| New picker sheet | `Features/Picker/` (alongside existing pickers) |
| New reusable view | `Shared/View/` |
| New design token | `Shared/Design/AppStyle.swift` |
| New utility | `Shared/Utilities/` |
| New service | Same feature folder or `Shared/` if cross-feature |
| New model | `Core/Model/` |
