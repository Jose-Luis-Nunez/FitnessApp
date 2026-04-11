# PROJECT_CONTEXT

## Data & Persistence

**Scope.** Persistent domain models live in `Packages/FitnessCore/Sources/FitnessCore/`: `Workout`, `Exercise`, `AnalyticsEntry`, `SetProgress` with `SetStatus`, and `MuscleCategoryGroup`. `WeightPhase` is a derived analytics shape (not loaded from its own file). `ExerciseEditMode` and `SetEditingMode` are UI flow enums, not stored entities.

**Entity map (logical).** `Workout` holds metadata and `selectedCategories`. `Exercise` instances are stored per workout via SwiftData relationships. `AnalyticsEntry` carries `exerciseId`, `date`, and embedded `[SetProgress]`.

ER (text): `WorkoutModel` (1) —cascade→ * `ExerciseModel`; `AnalyticsEntryModel` (1) —cascade→ * `SetProgressModel`; `AnalyticsEntryModel.exerciseId` links to `ExerciseModel.id` (logical, not a SwiftData relationship).

**Persistence strategy.** **SwiftData** is the primary persistence layer. `@Model` classes (`WorkoutModel`, `ExerciseModel`, `AnalyticsEntryModel`, `SetProgressModel`) live in `Packages/FitnessStorage/Sources/FitnessStorage/Models/`. A shared `ModelContainer` is registered as a Factory singleton (`\.modelContainer`). Each storage service creates its own `ModelContext`. **Current/default workout IDs** remain in `UserDefaults` (lightweight pointers). **Profile:** shell app uses `@AppStorage("userNickname")`. **Migration:** `DataMigrationService` runs on first launch to migrate legacy data to SwiftData (flag: `swiftdata_migration_complete`).

**Former persistence (pre-Phase 4).** **Workouts:** `UserDefaults` — `JSONEncoder`/`JSONDecoder` on `[Workout]` (`stored_workouts`), plus UUID strings for current and default workout ids. **Exercises:** app **Documents** — `workout_{uuid}_{category}_{userId}.json`. Legacy `exercises_{category}_{userId}.json` is read once and copied into the first workout’s per-workout files when a workout-scoped file is missing. **Analytics:** Documents — `analytics_{exerciseId}_{userId}.json` with ISO-8601 dates. **User id for paths:** `UserDefaults` key `userId` (created on first use) suffixes exercise and analytics filenames. **Profile:** shell app uses `@AppStorage("userNickname")`. No SwiftData or Core Data in this stack.

**Resolved risks (Phase 4).** `Workout.exerciseData: [String: Any]` removed (was dead code). `userId`-based file paths eliminated. Orphan exercise/analytics file risk eliminated (cascade delete rules). `try?` encode/decode replaced with do/catch.

**Remaining weaknesses.** Workout duplication reuses `Exercise.id`, coupling analytics across copies. Structured triggers, impact, and paths: **Risk Inventory**.

## UI & State

**Scope.** SwiftUI screens and components live in `FitnessApp/Features/` (shell app), `FitnessApp/Shared/` (Live Activity + widget, launch strategies only), and in SPM packages under `Packages/*/Sources/` (FitnessExercise, FitnessAnalytics, FitnessTraining, FitnessSchedule, FitnessUI). There is no `Shared/View/` or `Shared/Components/` tree; reusable feature and design-system UI live in SPM targets.

**State inventory (usage counts across all `*.swift` files that declare a `View` body, ~47 files).**

| Wrapper | Approx. count | Typical role |
|--------|----------------|--------------|
| `@State` | 71 | Sheet visibility, picker animation, local form mirrors (e.g. seat parts), filter UI, calendar month |
| `@ObservedObject` | 27 | Injected coordinators, card/form VMs, storage service in dropdown |
| `@Binding` | 24 | Sheets, pickers, shared numeric fields |
| `@StateObject` | 13 | Owned VMs at root screens (`WorkoutsScreen`, `ScheduleView`, `MuscleCategoryView`, app entry), long-lived coordinators |
| `@EnvironmentObject` | 13 | `AppRouter`, `UIOverlayState` for global navigation and overlays |
| `@Environment(...)` | 6 | `safeAreaInsets`, `dismiss` |
| `@AppStorage` | 1 | Profile nickname persistence |

`@Published` appears on `ObservableObject` types (ViewModels/services), not on `View` structs. `@FocusState` / `@SceneStorage` were not found in view sources. `@Namespace` appears for matched geometry (e.g. category selection).

**Duplicated / layered state.** `WorkoutsViewModel` mirrors `WorkoutStorageService`’s published fields via Combine `assign`, so workout lists and selection exist as a bound copy on the VM while persistence remains the service. Training flows use `SessionTrainingCache` for shared `ActiveSetViewModel` per category alongside per-screen `StateObject` coordinators and analytics VMs. Several flows keep short-lived `@State` copies (e.g. calendar `tempDate`, numeric pad display) beside bound or model data.

**Largest Swift files (by lines; excludes `.build/`, `Package.swift`).** `TotalAnalyticsViewModel.swift` (727), `AnalyticsView.swift` (626), `MuscleCategorySelectionView.swift` (624), `TotalAnalyticsView.swift` (597), `AnalyticsViewModel.swift` (547). **Other large views (>150 lines).** `CustomNumberPadView.swift` (446), `MuscleCategoryView.swift` (353), `IdleActiveCardView.swift` (327), `WorkoutsScreen.swift` (312), `BottomActionBarView.swift` (306), `ExercisePickerView.swift` (298), `AddAnalyticsEntryView.swift` (274), `ScheduleCalendarView.swift` (218), `TrainingView.swift` (214), `InactiveCardView.swift` (212), `TrainingSessionComponent.swift` (202), `CategoryTileView.swift` (190), `BottomMenuBarView.swift` (190), `ActiveCardView.swift` (189), `SimpleActiveSetView.swift` (173), `ExercisePickerShared.swift` (158), `ExerciseNamePickerView.swift` (157).

**UX patterns (loading / error / empty).** There is no widespread use of `ProgressView()`; readiness is often handled with flags (e.g. training `isInitialLoad`) or conditional layout. Empty content is handled locally: dedicated empty UI in places like analytics lists and schedule day detail, plus conditional branches when collections are empty. Errors and confirmations use `.alert` and sheet validation (e.g. profile nickname); patterns vary by feature rather than one shared empty/error component.

## Module Structure

**Scope.** All `*.swift` under the repo excluding `.build/` (~106 implementation files, ~15 test targets’ sources, eight `Package.swift` manifests; ~129 Swift files total). The iOS app target links every feature SPM product plus `FitnessCore`, `FitnessStorage`, `FitnessUI`, `FitnessResources`.

### File inventory (function × owning module)

- **Views:** *FitnessApp* — workouts (`WorkoutsScreen`, create/rename), `TrainingView`, `BottomMenuBarView`, `ProfileView`, Live Activity + Widget SwiftUI; *FitnessExercise* — muscle selection/category, cards (active/idle/inactive), pickers (name/weight/seat/icon), tiles; **note:** `ActiveSetEditPickerView.swift` here duplicates the `public` picker type in `FitnessUI` (training stack imports `FitnessUI`). *FitnessTraining* — `TrainingSessionComponent`, `TrainingActionBarComponent`, `TrainingPickerComponent`, `BottomActionBarView`, `SimpleActiveSetView`, picker row, glass compat; *FitnessAnalytics* — `AnalyticsView`, `TotalAnalyticsView`, `AnalyticsTileViews`, `CalendarGridView`, `CalendarDialogView` (tap “Last Workout Completion” / “Training Rhythm” for `AnalyticsDetailSection` drill-downs), `CustomNumberPadView`, `AddAnalyticsEntryView`; *FitnessSchedule* — `ScheduleView`, calendar, day detail, streak, week summary; *FitnessUI* — `WorkoutFormSheet`, `WorkoutDropdownView` / `WorkoutPickerView`, picker chrome, `MiniActionMenuView`, `ActiveSetEditPickerView`, `CapsuleToggleStyle`, shared modifiers/styles.
- **ViewModels / coordinators:** *FitnessApp* — `WorkoutsViewModel`; *FitnessExercise* — `MuscleCategoryViewModel`, `MuscleCategorySelectionViewModel`, `ExerciseCardViewModel`, `ExerciseFormViewModel`; *FitnessTraining* — `TrainingCoordinator`, `BottomActionBarViewModel`, `ActiveSetViewModel`; *FitnessAnalytics* — `AnalyticsViewModel`, `TotalAnalyticsViewModel`; *FitnessSchedule* — `ScheduleViewModel`.
- **Services:** *FitnessStorage* — `WorkoutStorageService`, `ExerciseStorageService`, `ExerciseManagementService`, `AnalyticsStorageService`, `TotalAnalyticsStorageService`; *FitnessTraining* — `SessionTrainingCache`, `TimerService`; *FitnessApp* — `TrainingActivityManager`, `AppLaunchStrategy` / `UITestLaunchStrategy`.
- **Models / protocols:** *FitnessCore* — domain models, progress/edit enums, `MuscleCategoryGroup`, `AnalyticsStoring`, `ExerciseStoring` (entity ↔ persistence layout: **Data & Persistence**); *FitnessApp* — Live Activity attribute types; *FitnessExercise* — `NavigationDestination`, `AppRouter`; *FitnessResources* — `L10n`.
- **Utilities / extensions:** *FitnessUI* — `AppStyle`, `WeightFormatter`, `TimeFormatter`, `DateFormatterUtility`, `AnalyticsDateHelper`, `WeightOptionsGenerator`, `Color+Extension`, `SafeAreaInsetsKey`, `SwipeBackGestureModifier`, `View+Toolbar`, `TrainingIDs`, `UIOverlayState`, `MuscleCategoryGroup+UI`; *FitnessAnalytics* — `ProgressChartCalculator`; *FitnessExercise* — `ExerciseAccessibilityIDs`; *FitnessTraining* — `TrainingGlassEffectCompat`; UITest — `ElementActions`, `TestFixtures.swift` / `ExerciseFixtures.swift` (`TestExerciseFixture`), `AccessibilityIDs`.
- **Tests:** `FitnessAppTests`; `FitnessAppUITests` (`BaseTest`, `TrainingUITests`, config/DSL); package tests — `FitnessExerciseTests`, `FitnessTrainingTests`, `FitnessAnalyticsTests`.
- **Other:** `FitnessAppApp.swift` (composition root); eight `Package.swift` files (manifests only).

### Collaboration map

- **Shared domain:** `FitnessCore` types and `*Storing` protocols are the hinge between UI/feature code and `FitnessStorage` services.
- **Navigation:** `FitnessAppApp` owns the `NavigationStack` switch, but `AppRouter` / `NavigationDestination` types live in `FitnessExercise`, with destination views spanning Exercise, Analytics, Schedule, Training, and App targets.
- **Training session:** `FitnessTraining` coordinator + cache + timer bind to `FitnessExercise` card/picker UI and `FitnessUI` tokens/sheets; workout selection often flows through `WorkoutDropdownView` / storage services.
- **Analytics:** VMs in `FitnessAnalytics` read/write via analytics storage services on `FitnessCore` models; chart math isolated in `ProgressChartCalculator`. `TotalAnalyticsViewModel` colocates aggregate DTOs (`WorkoutDetailData`, `CategoryProgressData`, `ExerciseProgressSummary`, …) with the class; `AnalyticsViewModel` adds reps-based series (`getDailyRepsProgression`, `repsPhases`) alongside weight phases.

### Workflow map

- **Workouts (list / create / rename):** `WorkoutsScreen` + `WorkoutsViewModel` + `WorkoutStorageService` + `CreateWorkoutView` / `RenameWorkoutView` + `FitnessCore.Workout`.
- **Train (category → exercise → sets):** `MuscleCategorySelectionView` (overview vs list, scroll-hiding filter bar, `WorkoutDropdownView` + `WorkoutPickerView` overlay, embedded `TrainingActionBarComponent` / `TrainingPickerComponent`; `init` builds `TrainingCoordinator` with a shared `AnalyticsViewModel`) → `MuscleCategoryView` (+ VMs) → `TrainingView` + `TrainingCoordinator` / `TrainingSessionComponent` / `BottomActionBarView` + `SessionTrainingCache` + `ActiveSetViewModel`.
- **Analytics & totals:** `AnalyticsView` (`CalendarDialogView`, hill chart via `ProgressChartCalculator`, goal overlay `saveGoal`, `AddAnalyticsEntryView`, swipe-delete sets → `deleteSetFromEntry`) + VMs + `AnalyticsStorageService` / `TotalAnalyticsStorageService` + `CustomNumberPadView`. `TotalAnalyticsView` reads `WorkoutStorageService.shared` for header context; rollup logic treats a “training day” as a calendar day with **≥3 distinct exercises** in analytics (`getTrainingDays` in `TotalAnalyticsViewModel`).
- **Schedule:** `ScheduleView` + `ScheduleViewModel` + `ScheduleCalendarView` / `ScheduleDayDetailView` + streak/week views.
- **Exercise catalog / editing:** `ExerciseStorageService` / `ExerciseManagementService` + picker/form VMs and card views in `FitnessExercise`.
- **Live Activity:** `TrainingActivityManager`, widget + intents under `Shared/LiveActivity`, driven from app/training lifecycle.

### Natural module boundaries

- **Domain vs persistence:** `FitnessCore` vs `FitnessStorage` (protocol-backed) is already a clean split.
- **Design system vs features:** `FitnessUI` (tokens, formatters, shared chrome) vs journey packages (`FitnessExercise`, `FitnessTraining`, `FitnessAnalytics`, `FitnessSchedule`).
- **Shell vs feature:** `FitnessApp` composes routers, tabs, and first-party-only concerns (profile, launch, Live Activity); feature SPMs stay user-journey sized.
- **Possible future tighten:** relocate `AppRouter` / `NavigationDestination` next to the app entry if you want `FitnessExercise` to be purely exercise UI without global navigation ownership.

## Tests

**Scope (repo test sources; `.build/` excluded).** `FitnessAppTests/` (Xcode target), `FitnessAppUITests/`, and SPM tests under `Packages/FitnessAnalytics/Tests/`, `Packages/FitnessExercise/Tests/`, `Packages/FitnessTraining/Tests/`. No package test targets found for `FitnessCore`, `FitnessSchedule`, `FitnessUI`, or other `Packages/*` trees.

| Module / area | Unit tests | UI tests | Integration tests |
|---------------|------------|----------|-------------------|
| App (`FitnessAppTests`) | Placeholder only (`Testing` stub) | — | — |
| `FitnessAnalytics` | Yes (`AnalyticsViewModelTests`) | — | — |
| `FitnessExercise` | Yes (`ExerciseCardViewModelTests`, `MuscleCategoryViewModelTests`, `EnvironmentObjectContractTests`) | — | — |
| `FitnessTraining` | Yes (`TrainingCoordinatorTests`, `SessionTrainingCacheTests`) | — | — |
| `FitnessCore`, `FitnessSchedule`, `FitnessUI` | None in repo | — | — |
| Shell (XCUITest) | — | Yes (`TrainingUITests`: full training flow) | — |

**Quality.** SPM tests use Swift `Testing` (`@Suite` / `@Test`), `@testable import`, file-local model factories (`makeExercise`, `makeEntry`), and small protocol mocks (e.g. `MockAnalyticsStorage`). UI layer: `BaseTest` (`--uitesting`, `UITEST_CONFIG` JSON launch env, screenshots on failure, terminate in tearDown), `UITestLaunchConfig` / `UITestScreen`, fixtures (`TestExerciseFixture`, `ExerciseFixtures`), `ElementActions` DSL, `AccessibilityIDs`.

**Gaps.** App-target unit tests are placeholder-only; XCUITest covers one training journey, not schedule/analytics/workouts/profile/navigation breadth; no `FitnessCore` / `FitnessStorage` / `FitnessSchedule` / `FitnessUI` test targets; no standalone integration suite beyond UI + package unit tests (see **Risk Inventory**).

## Architecture

**Pattern.** The app is SwiftUI-first MVVM: `ObservableObject` types (`*ViewModel`, `TrainingCoordinator`) own feature state; `FitnessStorage` exposes concrete `*Service` classes for persistence. Training stacks `TrainingCoordinator` with `ActiveSetViewModel` and `SessionTrainingCache` (one active-set VM per `MuscleCategoryGroup`). `BottomActionBarViewModel` is an immutable struct of derived flags, not reactive state. `ExerciseFormViewModel` is local form/edit state. There is no TCA or a single strict MVC split; some timing and presentation logic still lives in views.

**Dependency map (high level).**

```
Views / Screens
  → @EnvironmentObject AppRouter, UIOverlayState (FitnessExercise / FitnessUI)
  → @StateObject / @ObservedObject feature VMs

WorkoutsViewModel → WorkoutStorageService
                  → ExerciseStorageService (ad hoc, e.g. exercise counts)

MuscleCategorySelectionViewModel → WorkoutStorageService, ExerciseManagementService
                                 → SessionTrainingCache (reset paths)

MuscleCategoryViewModel → ExerciseStoring, WorkoutStorageService
                        → ExerciseFormViewModel, ActiveSetViewModel (cache or injected)

TrainingCoordinator → ActiveSetViewModel, AnalyticsViewModel (+ closure callbacks to parents)

AnalyticsViewModel → AnalyticsStoring, ExerciseStorageService
                   → WorkoutStorageService.shared (`resolveLatestExercise`, `saveGoal`, `updateExerciseCompletionStatus` from `deleteSetFromEntry`)

TotalAnalyticsViewModel → TotalAnalyticsStorageService (also `analyticsStorage.load` per exercise)
                        → WorkoutStorageService.shared, `ExerciseStorageService()` (last-workout completion/detail vs current workout catalog)

ScheduleViewModel → TotalAnalyticsViewModel

ExerciseManagementService → ExerciseStorageService, AnalyticsStoring, WorkoutStorageService

ActiveSetViewModel → TimerService (Combine-based)

TrainingActivityManager (app) → ActivityKit / UIKit (Live Activities only)
```

`WorkoutStorageService` and storage implementations do not depend on ViewModels upward. Hubs are shared instances (`WorkoutStorageService.shared`, `SessionTrainingCache.shared`); no compile-time circular type dependency among VM ↔ service ↔ storage was found in this pass.

**Concurrency.** UI updates flow through `@Published` and Combine: `sink` / `assign` / `AnyCancellable` in selection and training types; `PassthroughSubject` on `AnalyticsViewModel` for cross-screen refresh signals. `DispatchQueue.main.async` appears after some analytics writes and in `TimerService` / parts of `TrainingCoordinator`. Swift `async`/`await` is rare and mostly `Task { @MainActor in … sleep }` for UI sequencing in training-related views. No app-defined actors showed up in the scanned sources.

**Navigation.** `NavigationDestination` plus `AppRouter` (`Packages/FitnessExercise/…/AppRouter.swift`) own `NavigationPath` and mutations (`navigate`, `pop`, `popToRoot`, `replaceAll`, scene helpers). `FitnessAppApp` wires `NavigationStack` and `navigationDestination(for:)` to feature views. ViewModels generally do not push routes; views and chrome call the router.

## Risk Inventory

- ~~**Risk:** Orphan exercise and analytics files after workout deletion~~ **RESOLVED (Phase 4):** SwiftData cascade delete rules handle cleanup automatically.

- ~~**Risk:** Silent corruption or loss of `Workout.exerciseData`~~ **RESOLVED (Phase 4):** `exerciseData` property removed (was dead code with 0 call sites).

- **Risk:** Duplicated workouts share analytics by `Exercise.id`  
  **Trigger:** `WorkoutStorageService.duplicateWorkout` copies exercises with unchanged IDs into new per-workout files.  
  **Impact:** `AnalyticsEntry` files keyed by `exerciseId` blend history across logically separate workouts.  
  **Affected files:** `Packages/FitnessStorage/Sources/FitnessStorage/WorkoutStorageService.swift`, `ExerciseStorageService.swift`, `AnalyticsStorageService.swift`

- **Risk:** Persistence failures appear as empty state, not recoverable errors  
  **Trigger:** I/O or `UserDefaults` write failures caught internally; services `print` and return empty arrays or skip saves.  
  **Impact:** User believes data is gone; no guided retry or diagnostics.  
  **Affected files:** `Packages/FitnessStorage/Sources/FitnessStorage/WorkoutStorageService.swift`, `ExerciseStorageService.swift`, `AnalyticsStorageService.swift`

- **Risk:** Low automated coverage on storage and non-training flows  
  **Trigger:** Refactor to filenames, decoding, or `NavigationDestination` without new tests.  
  **Impact:** Regressions ship unnoticed in data migration, routing, schedule, analytics, or shell tabs.  
  **Affected files:** `FitnessAppTests/FitnessAppTests.swift`, `FitnessAppUITests/Tests/TrainingUITests.swift`, `FitnessAppUITests/Base/BaseTest.swift`; absence of tests under `Packages/FitnessCore`, `Packages/FitnessStorage`

## Implicit Decisions

- **Persistence:** SwiftData for all domain data (workouts, exercises, analytics). `UserDefaults` retained only for current/default workout ID pointers and migration flag. Profile nickname via `@AppStorage`. `DataMigrationService` handles one-time migration from legacy JSON/UserDefaults on first launch.
- **Modularity:** Journey-shaped SPM features (`FitnessExercise`, `FitnessTraining`, …) with `FitnessCore` + `FitnessStorage` as the domain/persistence hinge; `FitnessUI` centralizes `AppStyle` and shared chrome.
- **Navigation ownership:** Global routing types (`AppRouter`, `NavigationDestination`) live in `FitnessExercise` while `FitnessAppApp.swift` hosts the `NavigationStack` wiring—shell vs. package boundary is a deliberate split (also noted as a possible future relocation under **Module Structure**).
- **Reactivity:** Combine (`@Published`, `assign`, `sink`) and main-queue `DispatchQueue`/`TimerService` patterns over widespread `async`/`await`; shared `.shared` service hubs for storage and `SessionTrainingCache`.
- **Testing stance:** Quality investment is concentrated in package unit tests (`FitnessAnalytics`, `FitnessExercise`, `FitnessTraining`) and one end-to-end training UI test, not in app-target units or persistence-focused suites.
