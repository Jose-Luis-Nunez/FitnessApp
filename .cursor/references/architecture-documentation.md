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
  MuscleGroupSelection/ — Home screen: muscle group category grid. MuscleCategorySelectionViewModel accepts optional `coordinatorCache`, `exerciseManagement`, `workoutStorage`, and `exerciseStorage` via constructor injection (defaults to Factory singleton). Observes `exerciseStorage.changeVersion` to reactively refetch exercises from storage.
  Picker/             — All picker sheets (exercise, weight, seat, icon, name, active-set edit)
  Schedule/           — Training calendar, streaks, week summary, day details (implementation: `Packages/FitnessSchedule` SPM target)
  Training/           — Training session screen
  Workouts/           — (removed; extracted into `Packages/FitnessWorkouts` SPM target)

Packages/
  FitnessProfile/     — SPM library for profile feature (`BMIService`, `ProfileViewModel`, `ProfileStore`). Depends on `FitnessUI`. Tests: `BMIServiceTests` (stubbed API), `ProfileViewModelTests`.
  FitnessTraining/    — SPM library mirroring training flow types from the app (`TrainingCoordinator`, active set VM/cache/timer, bottom action bar, session/picker components). Sources: `Packages/FitnessTraining/Sources/FitnessTraining/`.
  FitnessWorkouts/    — SPM library for the workouts feature: `WorkoutsScreen` (entry view), `WorkoutsViewModel` (workout CRUD + UI state; constructor-DI with Factory-container fallbacks, enforces "must keep ≥1 workout" invariant in `deleteWorkout`), `CreateWorkoutView`, `RenameWorkoutView`, `MuscleGroupTile`. Depends on `FitnessCore`, `FitnessStorage`, `FitnessUI`, `FitnessExercise` (for `AppRouter`). Tests: `WorkoutsViewModelTests` (via `MockWorkoutStorage` + `MockExerciseStorage`, constructor-injected; no `.serialized` needed).
  FitnessTestSupport/ — Shared test utilities: `makeExercise` factory, `MockAnalyticsStorage`, `StubAnalyticsStorage`, `MockExerciseStorage`, `MockWorkoutStorage` (mutates state on delete/rename/duplicate), `MockTotalAnalyticsStorage`, `waitUntil` with timeout assertion. Depends on `FitnessCore` + `Testing`.

Tests/
  FitnessAppUITests/      — UI tests (XCUITest)
  Packages/*/Tests/       — Package-level unit tests per SPM module
    FitnessAnalyticsTests/  — AnalyticsViewModelTests, TotalAnalyticsViewModelTests, SaveAnalyticsUseCaseTests, DeleteAnalyticsSetUseCaseTests, SaveOrReplaceAnalyticsUseCaseTests
    FitnessExerciseTests/   — MuscleCategorySelectionViewModelTests (categories, exercise counts, card VM cache, reset, find category, exercise mutations, coordinator completion integration, exercise stability), ExerciseFormViewModelTests, ResetAllExercisesUseCaseTests
    FitnessStorageTests/    — WorkoutStorageServiceTests (with SpyExerciseStorage for duplicate verification), ExerciseStorageServiceTests, AnalyticsStorageServiceTests, ExerciseAndAnalyticsStorageTests, DataMigrationServiceTests, ExerciseManagementServiceTests, TotalAnalyticsStorageServiceTests, DeleteWorkoutUseCaseTests, DuplicateWorkoutUseCaseTests, FeedbackStorageServiceTests, SaveFeedbackUseCaseTests. TestHelpers provides `makeWorkoutStorageService` and `NoOpExerciseStorage`.
    FitnessTrainingTests/   — TrainingCoordinatorTests (including FactoryIntegrationTests, StartTrainingEdgeCaseTests), TrainingCoordinatorCacheTests, StartTrainingUseCaseTests, CompleteSetUseCaseTests, FinishExerciseUseCaseTests, CancelTrainingUseCaseTests, ResetExerciseUseCaseTests, SessionTrainingCacheTests, ActiveSetViewModelTests, TimerServiceTests, FeedbackViewModelTests, TrainingCoordinatorFeedbackTests
    FitnessCoreTests/       — BodyRegionTests, ExerciseFeedbackTests
    FitnessScheduleTests/   — ScheduleViewModelTests
    FitnessWorkoutsTests/   — WorkoutsViewModelTests (create/rename/delete/duplicate/default workout, muscle group toggle, FAB flow, exercise-count aggregation; includes invariant test that `deleteWorkout` ignores the last remaining workout)

### TimerService (Clock abstraction)

`FitnessTraining.TimerService` injects a `TimerClock` protocol for deterministic tests. The default `SystemTimerClock` wraps `Date()`; tests substitute a `FakeClock` to advance time synchronously. `TimerService.elapsedSeconds()` is a synchronous derived query for unit tests. The `init(clock:tickInterval:)` initializer also accepts a short `tickInterval` (defaults to 1 s in production), which the live `Task`-based tick loop uses to publish into `timerSeconds` — tests shorten this to a few ms and advance the `FakeClock` to verify the publication path deterministically.
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
| `ExerciseFeedback` | `Packages/FitnessCore/Sources/FitnessCore/ExerciseFeedback.swift` | `id`, `exerciseId`, `date`, optional `energyLevel` (1...5), optional `painCategory` (`BodyCategory`), `painRegions` (`Set<BodyRegion>` — multi-select; may be empty), `symptoms` (`Set<Symptom>`), optional `note`. `hasAnyContent` gates persistence (empty feedback is skipped). |
| `BodyCategory` | `Packages/FitnessCore/Sources/FitnessCore/BodyCategory.swift` | Enum: `back`, `abs`, `chest`, `arm`, `legs`. `from(muscleGroup:)` maps `MuscleCategoryGroup` -> feedback category. |
| `BodyRegion` | `Packages/FitnessCore/Sources/FitnessCore/BodyRegion.swift` | Enum of 32 regions (neck L/R, shoulders L/R, upper/middle/lower back, abs, obliques L/R, chest L/R/full, biceps L/R, triceps L/R, forearm L/R, hand L/R, wrist L/R, thigh front/back/inner/outer, knees L/R, calf, foot, ankle). `category` maps each region to a `BodyCategory`, `regions(in:)` filters by category, `iconAssetName` returns the asset-catalog image name used by the pain-region grid (fehlende Assets → leerer Platz, Tile-Rahmen + Titel bleiben sichtbar). English display names. |
| `Symptom` | `Packages/FitnessCore/Sources/FitnessCore/Symptom.swift` | Enum: `pain`, `dizziness`, `nausea`, `muscleWeakness` |

## Services

All services are registered in a [hmlongco/Factory](https://github.com/hmlongco/Factory) DI container. Access via `@Injected(\.keyPath)` or `Container.shared.keyPath()`. No more `static let shared` singletons — use the container instead.

**Container registrations:**
- `Packages/FitnessStorage/Sources/FitnessStorage/StorageContainer.swift` — `workoutStorage`, `exerciseStorage`, `analyticsStorage`, `exerciseManagement`, `totalAnalyticsStorage`, `feedbackStorage`, `deleteWorkoutUseCase`, `duplicateWorkoutUseCase`, `saveFeedbackUseCase`
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/AnalyticsContainer.swift` — `saveAnalyticsUseCase`, `deleteAnalyticsSetUseCase`, `saveOrReplaceAnalyticsUseCase`
- `Packages/FitnessExercise/Sources/FitnessExercise/ExerciseContainer.swift` — `resetAllExercisesUseCase`
- `Packages/FitnessTraining/Sources/FitnessTraining/TrainingContainer.swift` — `sessionTrainingCache`, `trainingCoordinatorCache`, `startTrainingUseCase`, `completeSetUseCase`, `finishExerciseUseCase`, `cancelTrainingUseCase`, `resetExerciseUseCase`

| Service | File | Container Key | Scope | Purpose |
|---------|------|---------------|-------|---------|
| `WorkoutStorageService` | `Packages/FitnessStorage/.../WorkoutStorageService.swift` | `\.workoutStorage` | singleton | Workout CRUD, current workout selection, default workout. SwiftData-backed. Errors logged via `os.Logger`. Requires `ExerciseStoring` via constructor injection; accepts optional `ModelContainer` and `UserDefaults` (default to Factory singleton / `.standard`). Factory registration in `StorageContainer` passes `exerciseStorage` explicitly. Conforms to `WorkoutStoring` protocol (`FitnessCore`). |
| `ExerciseStorageService` | `Packages/FitnessStorage/.../ExerciseStorageService.swift` | `\.exerciseStorage` | singleton | Exercise persistence per workout/category. SwiftData-backed, `@Observable`. Exposes `changeVersion` (monotonic counter incremented on each successful write); ViewModels observe this to refetch from the single source of truth instead of maintaining local copies. Errors logged via `os.Logger`. Accepts optional `ModelContainer` via constructor injection (defaults to Factory singleton). Conforms to `ExerciseStoring` protocol (`FitnessCore`). |
| `ExerciseManagementService` | `Packages/FitnessStorage/.../ExerciseManagementService.swift` | `\.exerciseManagement` | singleton | Exercise business logic (add, remove, reorder). Conforms to `ExerciseManaging` protocol (`FitnessCore`). |
| `AnalyticsStorageService` | `Packages/FitnessStorage/.../AnalyticsStorageService.swift` | `\.analyticsStorage` | singleton | Per-exercise analytics entry persistence. SwiftData-backed. Errors logged via `os.Logger`. Accepts optional `ModelContainer` via constructor injection (defaults to Factory singleton). Conforms to `AnalyticsStoring` protocol (`FitnessCore`). |
| `TotalAnalyticsStorageService` | `Packages/FitnessStorage/.../TotalAnalyticsStorageService.swift` | `\.totalAnalyticsStorage` | singleton | Cross-exercise analytics loading, workout-scoped. Conforms to `TotalAnalyticsStoring` protocol (`FitnessCore`). |
| `FeedbackStorageService` | `Packages/FitnessStorage/.../FeedbackStorageService.swift` | `\.feedbackStorage` | singleton | Persists subjective post-exercise feedback (energy level, pain category + **multi-select** pain regions, symptoms, note). SwiftData-backed via `ExerciseFeedbackModel` (`painRegionsRaw: [String]`; legacy `painRegionRaw: String?` is still read at load time to merge pre-migration entries into the array). Conforms to `FeedbackStoring` protocol (`FitnessCore`). Multiple feedback entries per exercise are supported (append-only, sorted by date). |
| `DataMigrationService` | `Packages/FitnessStorage/.../DataMigrationService.swift` | — | static | One-time migration from JSON/UserDefaults to SwiftData. Runs on first launch after update. |
| `ModelContainer` | via `StorageContainer.swift` | `\.modelContainer` | singleton | Shared SwiftData container for all `@Model` types (`WorkoutModel`, `ExerciseModel`, `AnalyticsEntryModel`, `SetProgressModel`, `ExerciseFeedbackModel`). |
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
| `SaveFeedbackUseCase` | `Packages/FitnessStorage/.../UseCases/SaveFeedbackUseCase.swift` | `\.saveFeedbackUseCase` | Persists `ExerciseFeedback` via `feedbackStorage`. Returns `false` for empty feedback (skipped — nothing written). |

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
| `OverlaySheetContainer` | `Packages/FitnessUI/Sources/FitnessUI/ExercisePickerSheetChrome.swift` | Reusable overlay sheet with backdrop, grabber, swipe-dismiss, appear animation. Separates content (scrollable), actions (fixed bottom), and overlay (e.g. numpad). All picker sheets use this. Optional `backgroundColor` parameter (default `AppStyle.Color.sheetBackground`) overrides the sheet body fill — used by `FeedbackSheetView` to switch to `AppStyle.Color.black` for stronger contrast with the glass-effect tiles. |
| `ExercisePickerActionButtons` / `exercisePickerSheet` | `Packages/FitnessUI/Sources/FitnessUI/ExercisePickerSheetChrome.swift` | Shared picker sheet chrome (inner styling + action buttons) |
| `MetricChipView` | `Features/Exercise/ExerciseCard/MetricChipView.swift` | Generic chip container with background/stroke |
| `WeightPhaseTileView` | `Features/Exercise/ExerciseCard/WeightPhaseTileView.swift` | Weight/reps phase tile for analytics display |
| `CardBackground` | `Features/Exercise/ExerciseCard/CardBackground.swift` | Card wrapper with `Style` enum (`.glass`, `.gradient(Color)`) |
| `SetTileView` | `Features/Exercise/ExerciseCard/SetTileView.swift` | Completed set display tile (weight/reps) |
| `SetRowChipStyle` | `Features/Exercise/ActiveSet/SimpleActiveSetView.swift` | ViewModifier for set row chips — use `.setRowChipStyle(minWidth:)` |
| `FeedbackSheetComponent` | `Packages/FitnessTraining/.../Feedback/FeedbackSheetComponent.swift` | Presents `FeedbackSheetView` when `TrainingCoordinator.isFeedbackSheetPresented` is true. Instantiates `FeedbackViewModel` lazily per presentation, scoped to the current exercise and pre-selects the body category from the exercise's `MuscleCategoryGroup`. Sets `UIOverlayState.isEditingSheetVisible` while visible so the bottom action bar hides — matching `TrainingPickerComponent` and `MuscleCategoryView`. |
| `FeedbackSheetView` | `Packages/FitnessTraining/.../Feedback/FeedbackSheetView.swift` | Post-exercise feedback sheet using `OverlaySheetContainer` mit schwarzem Hintergrund (`AppStyle.Color.black`) für besseren Kontrast zu den Glass-Tiles. Sticky "How was the exercise?" title outside the scroll view, no height cap. Sections (top→bottom): Pain region (`PainRegionGrid`), Symptoms (`SymptomChipsView`), Energy level (`EnergyLevelSlider`), Note (multiline `TextEditor`). Save button disabled while the form is empty; cancel discards. All English copy. |
| `EnergyLevelSlider` | `Packages/FitnessTraining/.../Feedback/EnergyLevelSlider.swift` | Horizontal 1...5 slider (dark-green tint, `AppStyle.Color.greenDark`) with integer snap. `Low` / current value / `High` labels above, tick labels 1–5 below. Binds directly to `FeedbackViewModel.energyLevel`. Identifier `TrainingIDs.energyLevelSlider`. |
| `SymptomChipsView` | `Packages/FitnessTraining/.../Feedback/SymptomChipsView.swift` | 2-column `LazyVGrid` von gro\u00dfen `SymptomTile`s (Pain, Dizziness, Nausea, Weakness). Jeder Tile zeigt einen Icon-Kreis (mit Glow bei Selektion), UPPERCASE-Titel (`Symptom.displayName`) und Subtitle (`Symptom.description`, z.B. "Acute or sharp discomfort"). Highlight via `AppStyle.Color.greenGlow` (Border + Title + Icon) plus leichte gr\u00fcne Tile-T\u00f6nung. Tile-Hintergrund über `TrainingGlassEffectCompat.rectCard` (Liquid Glass auf iOS 26+, `ultraThinMaterial` sonst); grüne Tile-Tönung wird zusätzlich auf das Glas gelegt. SF-Symbol-Icons: `bolt.fill`, `tornado`, `face.dashed`, `dumbbell.fill`. |
| `PainRegionGrid` | `Packages/FitnessTraining/.../Feedback/PainRegionGrid.swift` | 3-column `LazyVGrid` of `PainRegionTile`s, pre-scoped to the exercise's `BodyCategory`. **Multi-select**: `selectedRegions: Set<BodyRegion>` + `onToggle` — beliebig viele Regionen können gleichzeitig aktiv sein (z. B. Lower back + Obliques). Image-only Tiles (120pt hoch, `scaledToFit`) mit `TrainingGlassEffectCompat.rectCard` als Tile-Hintergrund (Liquid Glass auf iOS 26+, `ultraThinMaterial` sonst); kein Text-Label — der Regions-Name dient nur als `accessibilityLabel` für VoiceOver. Selektion durch grünen Rahmen + weicher Glow-Kreis; Tippen auf ein bereits ausgewähltes Tile entfernt es aus der Auswahl (ersetzt die frühere "None"-Option des Wheel-Pickers). Asset-Name pro Region via `BodyRegion.iconAssetName`; fehlende Assets → leerer Kasten (nur Rahmen, kein Inhalt). |


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
| `TrainingCoordinator` | `Packages/FitnessTraining/.../TrainingCoordinator.swift` | Thin state-holder + orchestrator; delegates business logic to Use Cases via `@Injected` (`startTrainingUseCase`, `completeSetUseCase`, `finishExerciseUseCase`, `cancelTrainingUseCase`, `resetExerciseUseCase`) |
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

`backgroundColor`, `primaryButton`, `exerciseCardBackground`, `chipsBackground`, `white`, `black`, `yellow`, `gray`, `grayDark`, `greenBlack`, `greenDark`, `green`, `greenLight`, `greenGlow`, `sheetBackground`, `sheetInputBackground`, `metricChipBackground`, `progressTrack`, `numberPadGray`, `trainingAccent`, `inProgressGold`, `profileCardBackground`, `bmiUnderweight`, `bmiNormal`, `bmiOverweight`, `bmiObese`, `painAccent` (red/orange for the feedback-sheet entry icon in `BottomActionBarView`)

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
