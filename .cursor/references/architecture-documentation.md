# FitnessApp Architecture

## Architectural Decisions (ADRs)

Project-wide architectural decisions live in [`docs/adr/`](../../docs/adr/README.md). Each ADR is immutable once accepted; new decisions supersede via a fresh ADR.

| ID | Title | Status |
|----|-------|--------|
| [0001](../../docs/adr/0001-model-as-ui-source-of-truth.md) | @Model als UI Single Source of Truth | accepted |
| [0002](../../docs/adr/0002-persistence-ui-package.md) | FitnessPersistenceUI Package | accepted (T4 skeleton + T5 cards + T6 tile + T7-0 cycle-break + T7a tile rollout + T7b card rollout + T8a list-mode rollout landed) |
| [0003](../../docs/adr/0003-coordinator-session-contract.md) | Coordinator Session-State Vertrag | accepted |

When making a structural change that conflicts with an existing ADR, write a new ADR superseding the old one. The stop-hook `adr-required.sh` (T0d) reminds the agent to do so.

## Feature Map

```
Features/
  Analytics/          — Exercise analytics, charts, total analytics overview
  BottomBar/          — Bottom navigation bar, bottom action bar
    Profile/          — User profile: nickname, body data (weight/height/age), BMI via API
  Exercise/
    ActiveSet/        — Active set tracking during training, timer service
    ExerciseCard/     — Card UI for exercises (idle, active, inactive states)
    MuscleCategory/   — Muscle category detail screen with exercises. **T7b**: `MuscleCategoryView.exerciseListSection` renders `ExerciseCardModelView` from `FitnessPersistenceUI` driven by a local `@Query<ExerciseModel>` filtered on `(workoutId, category)` — Bug 1 fixed live because the variant resolves from `model.isCompleted` instantly after `coordinator.finishExercise()` writes it. View identity is rebound on workout switch via `.id(viewModel.currentWorkoutId)`. **T8c**: the Mini-Menu "Start Training" router now also reads from the live `categoryModels` `@Query` (`categoryModels.first(where: { !$0.isCompleted })?.id`, post-T8d the navigation carries `exerciseId: UUID`) instead of `viewModel.exercises.first(where:)` — routing into a freshly-completed Exercise would have defeated the T7b live-fix. The `viewModel.exercises` snapshot remains the backing store for the edit/picker/form path (`add`, `updateExercise`, `deleteExercise`, `resetProgress`, `saveExercises`) and feeds the UI-affordance Bools (`showStartTraining`, `showReset`, `hasActiveExercise`, `hasCompletedExercises`) — these are routing-irrelevant Mini-Menu visibility flags where snapshot-latency is tolerable. **T8d**: removed the now-dead `cardViewModels: [UUID: ExerciseCardViewModel]` cache, the `startStorageObservation` polling loop, the `cardViewModel(for:)` / `invalidateCardViewModels()` accessors, and the `changeVersion: Int` counter from `ExerciseStoring` + `ExerciseStorageService` + `MockExerciseStorage`. `refreshExercises()` is **kept** as the form-path's sync trigger.
    Storage/          — Exercise persistence and management services
  MuscleGroupSelection/ — Home screen: muscle group category grid. MuscleCategorySelectionViewModel accepts optional `coordinatorCache`, `exerciseManagement`, `workoutStorage` via constructor injection (defaults to Factory singleton). The `exerciseStorage` parameter that existed transiently after T8d was removed in the post-audit cleanup — its previous consumer (`changeVersion`-driven `startStorageObservation` polling) is gone, and SwiftData `@Query` in the views is now the live read path. **T7a**: the overview-mode tile grid (`MuscleCategorySelectionView.categoryList`) renders `CategoryTileModelView` from `FitnessPersistenceUI` (gated on `viewModel.currentWorkoutId`) — Bug 2 fixed live because the tile's `@Query<ExerciseModel>` reacts to SwiftData writes without going through `refreshExercises()`. **T8a**: the list-mode (`allExercisesList`) now also renders `ExerciseCardModelView` driven by a local `@Query<ExerciseModel>` filtered on `workoutId` (no category filter — list-mode flattens all categories into one list, then sorts uncompleted-first). View identity is rebound on workout switch via `.id(viewModel.currentWorkoutId)`. **T8d**: deleted the legacy `cardViewModels: [UUID: ExerciseCardViewModel]` cache + `cardViewModel(for:category:)` accessor + `startStorageObservation` polling loop, and removed the `struct CategoryTileView` from `FitnessExercise` (its layout constants now live as `ExerciseCardLayout` in `FitnessUI`). The `viewModel.exercisesByCategory` snapshot remains as the form/picker write-path's backing store, refreshed via `refreshExercises()` from `.onAppear` and `startWorkoutObservation()`. **Post-T8 product fix**: `viewModel.categories` is now a `let` constant equal to `MuscleCategoryGroup.allCases` (sorted by rawValue). The overview tile-grid is workout-agnostic and always shows all 5 categories — `Workout.selectedCategories` is no longer read by any UI surface (it survives at the persistence layer for future use). Rationale: the per-category "New Exercise" Mini-Menu always lists all categories, so a workout with `selectedCategories = [.abs]` could legitimately accumulate Schulter/Brust/Bein-exercises that the overview would silently hide while list-mode (no category filter) shows them — a class of "missing tile" bug. Pinning `categories = allCases` makes both view modes consistent. The `startWorkoutObservation()` task now only re-runs `refreshExercises()` on workout switch (the categories list is no longer derived from the workout).
  Picker/             — All picker sheets (exercise, weight, seat, icon, name, active-set edit)
  Schedule/           — Training calendar, streaks, week summary, day details (implementation: `Packages/FitnessSchedule` SPM target)
  Training/           — Training session screen. `TrainingView` is parameterised by `exerciseId: UUID` (resolved via `@Query<ExerciseModel>` filtered by id) and renders `ExerciseCardModelView` from `FitnessPersistenceUI`. Coordinator APIs (`TrainingCoordinator.startTraining(for:)`, `TrainingActionBarComponent`) take the DTO `Exercise` and are bridged with `model.toDomain()` at the call site.
  Workouts/           — (removed; extracted into `Packages/FitnessWorkouts` SPM target)

Packages/
  FitnessProfile/     — SPM library for profile feature (`BMIService`, `ProfileViewModel`, `ProfileStore`, `BVGTramService`, `TramDeparturesViewModel`, `TramDeparturesCardView`, `TramDeparturesCache`). Depends on `FitnessUI`. Tests: `BMIServiceTests` (stubbed API), `ProfileViewModelTests`, `BVGTramServiceTests` (stubbed API), `TramDeparturesViewModelTests` (MockService + MockCache), `TramDeparturesCacheTests` (ephemerer `UserDefaults(suiteName:)`). Die Tram-Sub-Feature rendert eine aufklappbare Karte am Ende der Profile-Seite mit Start↔Destination-Swap (horizontaler Pfeil), englischen Captions und einem `RefreshActionButton` aus `FitnessUI` als manueller Refresh-Trigger. Die nächsten 3 Tram-21-Abfahrten zwischen Blockdammweg (`900162504`) und Marktstr. (`900160535`) werden aus `v6.bvg.transport.rest/stops/{id}/departures` geholt. **Polling-Strategie (event-driven)**: Initial-Refresh on toggleExpanded; periodisches 60 s Refresh-Intervall solange aufgeklappt **und** App `.active`; ScenePhase-Handler stoppt Polling bei `.inactive`/`.background` und ruft `onBecameActive()` bei Foreground-Return auf — letzterer triggert Sofort-Refresh nur wenn `lastUpdated > 60 s` her. **Polling ist NICHT an View-Lifecycle gekoppelt**: Tab-Wechsel (Profile → Home → Profile) lässt den Auto-Refresh weiterlaufen, solange die Karte aufgeklappt ist und die App `.active` ist. Die einzigen Stopper sind explizites `toggleExpanded` (Collapse) und der Scene-Phase-Handler. Ein früher vorhandenes `.onDisappear { stopAutoRefresh() }` wurde Apr 2026 entfernt, weil es nach Tab-Rückkehr die Karte stumm geschaltet hat ohne Mehrwert (Battery-Save übernimmt schon der Scene-Phase-Pfad). Pin: `TramDeparturesViewModelTests.toggleExpanded_pollingContinuesAcrossMultipleCycles`. Auf Netz-Fehlschlag wird der UserDefaults-Cache (`TramDeparturesCache`, Key `tram.cache.<line>.<from>.<to>`) als Fallback gezeigt mit `isStale=true` und gelbem "No internet · cached HH:mm"-Footer. BMI- und Körperdaten-Karten in `ProfileView` nutzen das gleiche Aufklapp-Pattern (lokaler `@State`, kein explizites `.transition`/`.animation` — implizite SwiftUI-Default-Animation wie `InactiveCardModelView`).
  FitnessTraining/    — SPM library mirroring training flow types from the app (`TrainingCoordinator`, active set VM/cache/timer, bottom action bar, session/picker components). Sources: `Packages/FitnessTraining/Sources/FitnessTraining/`. Also exposes `FitnessTrainingTestSupport` library with `FakeClock` (deterministic `TimerClock` for tests).
  FitnessWorkouts/    — SPM library for the workouts feature: `WorkoutsScreen` (entry view), `WorkoutsViewModel` (workout CRUD + UI state; constructor-DI with Factory-container fallbacks, enforces "must keep ≥1 workout" invariant in `deleteWorkout`), `CreateWorkoutView`, `RenameWorkoutView`, `MuscleGroupTile`. Depends on `FitnessCore`, `FitnessStorage`, `FitnessUI`, `FitnessExercise` (for `AppRouter`). Tests: `WorkoutsViewModelTests` (via `MockWorkoutStorage` + `MockExerciseStorage`, constructor-injected; no `.serialized` needed).
  FitnessTestSupport/ — Shared test utilities: `makeExercise` factory, `MockAnalyticsStorage`, `StubAnalyticsStorage`, `MockExerciseStorage`, `MockWorkoutStorage` (mutates state on delete/rename/duplicate), `MockTotalAnalyticsStorage`, `MockExerciseManagement` (full `ExerciseManaging` impl with spy fields `updatedExercises`/`resetExercises`), `InMemoryFeedbackStorage` (upsert-by-sessionId `FeedbackStoring`), `waitUntil` (throws `WaitUntilTimeoutError` on timeout), `TestTags` (Swift Testing `Tag` extensions: `.fast`, `.snapshot`, `.integration`, `.ui` for selective test runs via Xcode test plans or `xcodebuild -only-testing-tags`). Depends on `FitnessCore` and `Mockable`. No explicit `swift-testing` SPM dependency — `import Testing` resolves from the Xcode toolchain (Xcode 16+). This was cleaned up to eliminate the `_TestingInternals` module conflict that blocked adoption of macro-based libraries (Mockable, swift-snapshot-testing, etc.). **Mockable adoption**: all 6 FitnessCore protocols (`ExerciseStoring`, `AnalyticsStoring`, `FeedbackStoring`, `WorkoutStoring`, `ExerciseManaging`, `TotalAnalyticsStoring`) are annotated `@Mockable`, generating `MockExerciseStoring`, `MockAnalyticsStoring`, `MockFeedbackStoring`, `MockWorkoutStoring`, `MockExerciseManaging`, `MockTotalAnalyticsStoring` (available in debug builds via `MOCKING` flag). These replace hand-written stubs where appropriate (e.g. `NoOpExerciseStorage` → `MockExerciseStoring(policy: .relaxedVoid)` + catch-all `given`). Complex behavioral fakes (e.g. `MockWorkoutStorage`, `InMemoryFeedbackStorage`) are retained for tests that depend on their stateful logic.
  FitnessPersistenceUI/ — Primary SwiftUI integration surface for SwiftData `@Model`s. Allowed `@_spi(PersistenceUI) import FitnessStorage` consumers are: this package, `FitnessStorage`'s own tests (`@_spi(PersistenceUI) @testable import`), and specific `@Query`-host views in `FitnessExercise` added in T7a/T7b/T8a (`MuscleCategorySelectionView`, `MuscleCategoryView`). Each new SPI consumer is review-required (ADR-0002). T5 shipped the first pilot: `ExerciseCardModelView` (variant-resolver Container) plus three live-bound variant views — `ActiveCardModelView`, `IdleActiveCardModelView`, `InactiveCardModelView` — each declared `@_spi(PersistenceUI) public struct` because their public API carries `@Bindable model: ExerciseModel` (an SPI-only type). All four views read directly from `model.X` (no `ExerciseCardViewModel` snapshot) and the Container resolves `CardVariant` live from `model.isCompleted` via `FitnessCore.resolveCardVariant` — fixing Bug 1's data path. T6 shipped `CategoryTileModelView` (`@_spi(PersistenceUI) public struct`) which scopes its rendering data to `(workoutId, category)` via `@Query<ExerciseModel>` with a `#Predicate` on the denormalised `workoutId` (T3 schema; avoids §14a/§14b predicate anti-patterns). Total/active/completed counts are aggregated live from the query result — fixing Bug 2's data path. The `hasActiveSetForCategory: Bool` and `onTap` callback stay plain-param boundaries (analog T5: session/navigation state lives outside the view). T7-0 broke the `FitnessPersistenceUI → FitnessExercise` dependency cycle by hoisting reusable building blocks (`CardVariant` + `resolveCardVariant`, `ExerciseCardLayout` constants, `CardBackground`, `MetricChipView`, `ProgressBar`, `SetTileView`, `WeightPhaseTileView`, `ExerciseCardResetButton`, `HomeIDs`/`MuscleCategoryIDs`/`ExerciseIDs`/`ExerciseCardIDs`) into `FitnessCore` (logic + identifiers) and `FitnessUI` (rendering). Result: this package depends on `FitnessCore`, `FitnessStorage`, `FitnessUI`, `FitnessAnalytics`, `FitnessTraining` only — no `FitnessExercise` import. T7a then added the reverse edge: `FitnessExercise → FitnessPersistenceUI` (`@_spi(PersistenceUI) import FitnessPersistenceUI`) so `MuscleCategorySelectionView.categoryList` can render `CategoryTileModelView` (live Bug-2 fix). T7b applied the analogous switch in `MuscleCategoryView.exerciseListSection` (live Bug-1 fix). T8a routed `MuscleCategorySelectionView.allExercisesList` through `ExerciseCardModelView` and T8d deleted the now-orphaned `struct CategoryTileView` from `FitnessExercise` (its layout constants now live as `ExerciseCardLayout` in `FitnessUI`). T8d/Training (final cleanup) deleted the legacy snapshot stack entirely: `ExerciseCardContainerView`, `IdleActiveCardView`, `ActiveCardView`, `InactiveCardView`, and `ExerciseCardViewModel` are gone. `TrainingView` now resolves the navigated `exerciseId: UUID` to a live `ExerciseModel` via `@Query` and renders `ExerciseCardModelView` directly — same live-bind path the rest of the app already used. `NavigationDestination.training` now carries `(exerciseId: UUID, category: MuscleCategoryGroup)` to keep `ExerciseModel`'s `@_spi` boundary out of the navigation enum. Module also exposes `ExerciseModel+UI` (`@_spi(PersistenceUI)` extension: `hasWeight`, `displayIconName`, `categoryGroup`, `iconAlignment`) so the variant views can read UI-shape conveniences without snapshotting via `model.toDomain()`. See [ADR-0001](../../docs/adr/0001-model-as-ui-source-of-truth.md), [ADR-0002](../../docs/adr/0002-persistence-ui-package.md).

Tests/
  FitnessAppUITests/      — UI tests (XCUITest). `TrainingUITests` (full training flow)
  Packages/*/Tests/       — Package-level unit tests per SPM module
    FitnessAnalyticsTests/  — AnalyticsViewModelTests, TotalAnalyticsViewModelTests, SaveAnalyticsUseCaseTests, DeleteAnalyticsSetUseCaseTests, SaveOrReplaceAnalyticsUseCaseTests
    FitnessExerciseTests/   — MuscleCategorySelectionViewModelTests (categories, exercise counts, reset, find category, exercise mutations, exercise stability, **T7a `currentWorkoutId` exposure**), MuscleCategoryViewModelTests (mutations, refresh-on-coordinator-completion, **T7b `currentWorkoutId` exposure**), ExerciseFormViewModelTests, ResetAllExercisesUseCaseTests. T8d removed the `card VM cache` / `coordinator completion integration` suites along with the polling+caching architecture they exercised.
    FitnessStorageTests/    — WorkoutStorageServiceTests (duplicate verification now uses Mockable-generated `MockExerciseStoring` with `given`/`verify` DSL instead of hand-written `SpyExerciseStorage`), ExerciseStorageServiceTests, AnalyticsStorageServiceTests, ExerciseAndAnalyticsStorageTests, DataMigrationServiceTests, ExerciseManagementServiceTests, TotalAnalyticsStorageServiceTests, DeleteWorkoutUseCaseTests, DuplicateWorkoutUseCaseTests, FeedbackStorageServiceTests (incl. **per-session upsert**: `saveInsertsWhenSessionIsNew`, `saveUpdatesInPlaceWhenSessionAlreadyExists`, `saveUpdatedRecordReplacesAllFields`, `twoDifferentSessionsForSameExerciseKeepBothRows`, `twoSessionsOnSameDayBothPersist`), SaveFeedbackUseCaseTests, LoadLatestFeedbackUseCaseTests. TestHelpers provides `makeWorkoutStorageService` and `makeNoOpExerciseStoring()` (Mockable-based, replaces hand-written `NoOpExerciseStorage`). LegacyMigrationServiceInitOrderingTests and WorkoutStorageServiceHealingTests also migrated from `NoOpExerciseStorage` to `MockExerciseStoring`.
    FitnessTrainingTests/   — TrainingCoordinatorTests (including FactoryIntegrationTests, StartTrainingEdgeCaseTests), TrainingCoordinatorCacheTests, StartTrainingUseCaseTests, CompleteSetUseCaseTests, FinishExerciseUseCaseTests, CancelTrainingUseCaseTests, ResetExerciseUseCaseTests, ActiveSetViewModelTests, ActiveSetViewModelTimerResetTests (parametrized timer-reset + forwarding tests using `FakeClock` from `FitnessTrainingTestSupport`), TrainingStateMachinePropertyTests (property-based: 200 random action sequences per test, 7 invariants incl. `isLastSetCompleted ⇒ !isSetInProgress`, seeded RNG for reproducibility), BottomActionBarViewModelTests (incl. QuickDone→BottomActionBar E2E), TimerServiceTests, FeedbackViewModelTests (incl. draft store integration + per-session prepopulate + per-session upsert), FeedbackPerSessionFlowTests (end-to-end coordinator + draft store + storage), TrainingCoordinatorFeedbackTests, ExerciseFeedbackDraftStoreTests, FeedbackEntryIconResolverTests (incl. session-id scoping), TrainingCoordinatorDraftLifecycleTests
    FitnessUITests/          — Snapshot tests (swift-snapshot-testing, 21 tests): CardBackgroundSnapshotTests (gradient/glass/no-padding), MiniActionMenuSnapshotTests (with-title/no-title/confirm-delete), WorkoutDropdownSnapshotTests (collapsed/expanded/long-name), SetTileViewSnapshotTests (with-weight/bodyweight), ProgressBarSnapshotTests (empty/partial/full), MetricChipViewSnapshotTests (default/wide), CapsuleToggleStyleSnapshotTests (on/off), IdlePlayButtonSnapshotTests (idle), RefreshActionButtonSnapshotTests (ready/loading). Reference PNGs in `__Snapshots__/`.
    FitnessCoreTests/       — BodyRegionTests, ExerciseFeedbackTests
    FitnessScheduleTests/   — ScheduleViewModelTests
    FitnessWorkoutsTests/   — WorkoutsViewModelTests (create/rename/delete/duplicate/default workout, muscle group toggle, FAB flow, exercise-count aggregation; includes invariant test that `deleteWorkout` ignores the last remaining workout)
    FitnessPersistenceUITests/ — PackageSetupTests (3 smoke-tests: module-version export, in-memory ModelContainer build, cross-module @Model property round-trip via `@_spi(PersistenceUI)`); ExerciseCardModelViewTests (T5: 4 ResolveVariant logic tests + 1 Bug-1 sanity test that mutates `model.isCompleted` on a real in-memory ModelContainer and asserts the resolved variant flips from `.idle` to `.completed`); CategoryTileModelViewTests (T6: 4 tests proving the `(workoutId, category)` predicate against a real in-memory `ModelContainer` — count aggregation, workout isolation, Bug-2 sanity that `isCompleted = true` mutation drops the active-count, and empty-workout zero-count)

### TimerService (Clock abstraction)

`FitnessTraining.TimerService` injects a `TimerClock` protocol for deterministic tests. The default `SystemTimerClock` wraps `Date()`; tests substitute a `FakeClock` to advance time synchronously. `TimerService.elapsedSeconds()` is a synchronous derived query for unit tests. The `init(clock:tickInterval:)` initializer also accepts a short `tickInterval` (defaults to 1 s in production), which the live `Task`-based tick loop uses to publish into `timerSeconds` — tests shorten this to a few ms and advance the `FakeClock` to verify the publication path deterministically.
```

## Domain Models

Located in `Core/Model/`.

| Model | File | Key Properties |
|-------|------|----------------|
| `AnalyticsEntry` | `AnalyticsEntry.swift` | `id`, `exerciseId`, `date`, `setProgress` |
| `Exercise` | `Exercise.swift` | `id`, `name`, `weight`, `reps`, `sets`, `seatSetting`, `noSeats`, `isCompleted`, `iconName`, `category`, `goal`. **Note:** `Equatable`/`Hashable` use only `id` — do not use `==` to detect content changes; compare fields explicitly when needed or rely on SwiftData `@Model` / `@Query` as the UI source of truth (ADR-0001). |
| `Workout` | `Workout.swift` | `id`, `name`, `createdDate`, `lastModified`, `selectedCategories` |
| `MuscleCategoryGroup` | `MuscleCategoryGroup.swift` | Enum: `arms`, `chest`, `back`, `legs`, `abs`. `displayName` is provided by `FitnessUI` extension (`MuscleCategoryGroup+UI.swift`), not in FitnessCore. |
| `SetProgress` | `SetProgress.swift` | `id`, `status` (enum: `notStarted`, `inProgress`, `completedDone/Less/More`), `currentReps`, `weight`. Conforms to `Identifiable`. |
| `WeightPhase` | `WeightPhase.swift` | `id`, `weight`, `sessionCount`, `durationDays`, `startSetsReps`, `startDate`, `endSetsReps`, `endDate`, `hasImproved`, `maxReps` |
| `SetEditingMode` | `SetEditingMode.swift` | Enum: `less`, `more`, `edit` |
| `ExerciseEditMode` | `ExerciseEditMode.swift` (SPM: `Packages/FitnessCore`) | Enum: `full`, `name`, `weight`, `seat` — shared with `FitnessTraining` |
| `ExerciseFeedback` | `Packages/FitnessCore/Sources/FitnessCore/ExerciseFeedback.swift` | `id`, `sessionId`, `exerciseId`, `date`, optional `energyLevel` (1...5), optional `painCategory` (`BodyCategory`), `painRegions` (`Set<BodyRegion>` — multi-select; may be empty), `symptoms` (`Set<Symptom>`), optional `note`. `sessionId` ties the feedback to a specific training session — two sessions of the same exercise on the same day produce two records (analytics-style). `hasAnyContent` gates persistence (empty feedback is skipped). |
| `BodyCategory` | `Packages/FitnessCore/Sources/FitnessCore/BodyCategory.swift` | Enum: `back`, `abs`, `chest`, `arm`, `legs`. `from(muscleGroup:)` maps `MuscleCategoryGroup` -> feedback category. |
| `BodyRegion` | `Packages/FitnessCore/Sources/FitnessCore/BodyRegion.swift` | Enum of 32 regions (neck L/R, shoulders L/R, upper/middle/lower back, abs, obliques L/R, chest L/R/full, biceps L/R, triceps L/R, forearm L/R, hand L/R, wrist L/R, thigh front/back/inner/outer, knees L/R, calf, foot, ankle). `category` maps each region to a `BodyCategory`, `regions(in:)` filters by category, `iconAssetName` returns the asset-catalog image name used by the pain-region grid (fehlende Assets → leerer Platz, Tile-Rahmen + Titel bleiben sichtbar). English display names. |
| `Symptom` | `Packages/FitnessCore/Sources/FitnessCore/Symptom.swift` | Enum: `pain`, `dizziness`, `nausea`, `muscleWeakness` |

## Services

All services are registered in a [hmlongco/Factory](https://github.com/hmlongco/Factory) DI container. Access via `@Injected(\.keyPath)` or `Container.shared.keyPath()`. No more `static let shared` singletons — use the container instead.

**Container registrations:**
- `Packages/FitnessStorage/Sources/FitnessStorage/StorageContainer.swift` — `workoutStorage`, `exerciseStorage`, `analyticsStorage`, `exerciseManagement`, `totalAnalyticsStorage`, `feedbackStorage`, `deleteWorkoutUseCase`, `duplicateWorkoutUseCase`, `saveFeedbackUseCase`
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/AnalyticsContainer.swift` — `saveAnalyticsUseCase`, `deleteAnalyticsSetUseCase`, `saveOrReplaceAnalyticsUseCase`
- `Packages/FitnessExercise/Sources/FitnessExercise/ExerciseContainer.swift` — `resetAllExercisesUseCase`
- `Packages/FitnessTraining/Sources/FitnessTraining/TrainingContainer.swift` — `trainingCoordinatorCache`, `startTrainingUseCase`, `completeSetUseCase`, `finishExerciseUseCase`, `cancelTrainingUseCase`, `resetExerciseUseCase`

| Service | File | Container Key | Scope | Purpose |
|---------|------|---------------|-------|---------|
| `WorkoutStorageService` | `Packages/FitnessStorage/.../WorkoutStorageService.swift` | `\.workoutStorage` | singleton | Workout CRUD, current workout selection, default workout. SwiftData-backed. Errors logged via `os.Logger`. Requires `ExerciseStoring` via constructor injection; accepts optional `ModelContainer` and `UserDefaults` (default to Factory singleton / `.standard`). Factory registration in `StorageContainer` passes `exerciseStorage` explicitly. Conforms to `WorkoutStoring` protocol (`FitnessCore`). |
| `ExerciseStorageService` | `Packages/FitnessStorage/.../ExerciseStorageService.swift` | `\.exerciseStorage` | singleton | Exercise persistence per workout/category. SwiftData-backed, `@Observable`. Errors logged via `os.Logger`. Accepts optional `ModelContainer` via constructor injection (defaults to Factory singleton). Conforms to `ExerciseStoring` protocol (`FitnessCore`). T8d removed the `changeVersion: Int` monotonic counter — live UI reads now flow through SwiftData `@Query` against `ExerciseModel` (see `FitnessPersistenceUI`). |
| `ExerciseManagementService` | `Packages/FitnessStorage/.../ExerciseManagementService.swift` | `\.exerciseManagement` | singleton | Exercise business logic (add, remove, reorder). Conforms to `ExerciseManaging` protocol (`FitnessCore`). |
| `AnalyticsStorageService` | `Packages/FitnessStorage/.../AnalyticsStorageService.swift` | `\.analyticsStorage` | singleton | Per-exercise analytics entry persistence. SwiftData-backed. Errors logged via `os.Logger`. Accepts optional `ModelContainer` via constructor injection (defaults to Factory singleton). Conforms to `AnalyticsStoring` protocol (`FitnessCore`). |
| `TotalAnalyticsStorageService` | `Packages/FitnessStorage/.../TotalAnalyticsStorageService.swift` | `\.totalAnalyticsStorage` | singleton | Cross-exercise analytics loading, workout-scoped. Conforms to `TotalAnalyticsStoring` protocol (`FitnessCore`). |
| `FeedbackStorageService` | `Packages/FitnessStorage/.../FeedbackStorageService.swift` | `\.feedbackStorage` | singleton | Persists subjective post-exercise feedback (energy level, pain category + **multi-select** pain regions, symptoms, note). SwiftData-backed via `ExerciseFeedbackModel` (`painRegionsRaw: [String]`; legacy `painRegionRaw: String?` is still read at load time to merge pre-migration entries into the array; `sessionId: UUID?` optional purely for lightweight migration of pre-session rows — production saves always provide a non-nil value). **Upsert semantics**: `save(_:)` fetches the existing model whose `sessionId` matches `feedback.sessionId`; if found, it updates the row in place via `ExerciseFeedbackModel.update(from:)`, otherwise it inserts a new row. Re-saving inside the same open sheet (Done -> reopen -> edit -> Save) overwrites the same row; two distinct sessions of the same exercise (e.g. user starts the exercise, finishes, starts again later the same day) produce two distinct rows — analytics-style one-row-per-completed-session semantics. Conforms to `FeedbackStoring` protocol (`FitnessCore`). |
| `DataMigrationService` | `Packages/FitnessStorage/.../DataMigrationService.swift` | — | static | One-time migration from JSON/UserDefaults to SwiftData. Runs on first launch after update. |
| `ModelContainer` | via `StorageContainer.swift` (delegates to `ModelContainerBootstrap.makeProductionContainer()`) | `\.modelContainer` | singleton | Shared SwiftData container for all `@Model` types (`WorkoutModel`, `ExerciseModel`, `AnalyticsEntryModel`, `SetProgressModel`, `ExerciseFeedbackModel`). Built via `ModelContainerBootstrap` (`Packages/FitnessStorage/.../ModelContainerBootstrap.swift`), which (a) opens the store as `Schema(versionedSchema: SchemaV2.self)` + `migrationPlan: AppMigrationPlan.self`, (b) on `loadIssueModelContainer` (pre-T3 stores written without a `VersionedSchema`) adopts the on-disk store as `SchemaV1` to stamp it with `(1,0,0)` and re-opens with the plan, (c) on irrecoverable failure quarantines the store files to a sibling `*.bak-<ts>/` directory rather than deleting them, **and (d) runs `DataMigrationService.migrateIfNeeded` on the freshly-opened container's main context before returning**. The (d) coupling is critical: any caller resolving `\.modelContainer` is guaranteed that legacy JSON/UserDefaults rows have already been imported, so a service like `WorkoutStorageService` cannot observe an empty store and seed an auto-default workout that hides the post-migration data (legacy-import startup race, originally surfaced Apr 2026). |
| `BMIService` | `Packages/FitnessProfile/Sources/FitnessProfile/BMIService.swift` | — | per-use | Fetches BMI from external API (bmicalculatorapi.vercel.app), parses category (Underweight/Normal/Overweight/Obesity), with BMI-value fallback for unknown categories. Conforms to `BMIServicing: Sendable` protocol (`fetchBMI(weightKg:heightM:)` + `calculateBMILocally(weightKg:heightM:)`) so `ProfileViewModel` can be unit-tested against a stub instead of hitting the real endpoint. Default init wires `URLSession.shared`; tests inject a `StubURLProtocol`-backed ephemeral session (same pattern as `BVGTramService`). |
| `BVGTramService` | `Packages/FitnessProfile/Sources/FitnessProfile/BVGTramService.swift` | — | per-use | Fetches live tram departures from `v6.bvg.transport.rest/stops/{id}/departures`. Filters by line name client-side, decodes `when`/`plannedWhen` via `.iso8601`, maps HTTP 429 to `.rateLimited`, 5xx to `.serverError`, malformed JSON to `.decoding`. Conforms to `BVGTramServicing` protocol so the view model can be tested with a `MockService`. Default init wires `URLSession.shared`; tests inject a `StubURLProtocol`-backed ephemeral session. |
| `TramDeparturesCache` | `Packages/FitnessProfile/Sources/FitnessProfile/TramDeparturesCache.swift` | — | per-use | Persistiert die letzte erfolgreiche `[TramDeparture]`-Antwort pro `(line, from, to)` in `UserDefaults` (Key `tram.cache.<line>.<from>.<to>`, JSON via `.iso8601`). Wird vom ViewModel im `init` und nach jedem fehlgeschlagenen Refresh als Fallback gelesen, sodass die Karte auch ohne Netz Daten zeigt (mit `isStale=true`-Flag und „No internet · cached HH:mm"-Footer). Conforms to `TramDeparturesCaching`; Tests injizieren `UserDefaults(suiteName:)`. |
| `TimerService` | `Packages/FitnessTraining/.../TimerService.swift` | — | per-use | Rest timer during active sets |
| `TrainingCoordinatorCache` | `Packages/FitnessTraining/.../TrainingCoordinatorCache.swift` | `\.trainingCoordinatorCache` | singleton | Per-category `TrainingCoordinator` cache. Conforms to `TrainingCoordinatorCaching` protocol. Ensures all views share the same coordinator per `MuscleCategoryGroup`. Use `coordinator(for:)` for category-scoped access, `findCoordinator(for:)` to locate the coordinator for a specific exercise. `ResetAllExercisesUseCase` iterates coordinators from this cache to cancel all active sessions. |
| `ExerciseFeedbackDraftStore` | `Packages/FitnessTraining/.../Feedback/ExerciseFeedbackDraftStore.swift` | — (owned by `TrainingCoordinator`) | per-coordinator | `@MainActor @Observable` single-slot, in-memory draft store for feedback that has not been persisted yet. Holds at most one `ExerciseFeedback` (the draft for the currently active exercise). Drafts are **never persisted** to SwiftData and are silently discarded when the active exercise changes (`handleActiveExerciseChange(to:)`), the training is cancelled, or the exercise is finished. Owned by `TrainingCoordinator` and consumed by both `FeedbackViewModel` (for autosave + prepopulation) and `FeedbackEntryIconResolver` (for the bottom-bar icon's "draft" state). |

### SwiftData Schema Versioning

Per ADR-0005, every schema change goes through `VersionedSchema` + `SchemaMigrationPlan`. Files live under `Packages/FitnessStorage/Sources/FitnessStorage/Schema/`:

| File | Purpose |
|---|---|
| `Schema/SchemaV1.swift` | `enum SchemaV1: VersionedSchema` — frozen pre-migration form. Snapshots `WorkoutModel` and `ExerciseModel` (Hybrid-Regel: changed class + Beziehungs-Closure-Regel for `WorkoutModel.exercises`-relationship); `SetProgressModel`, `AnalyticsEntryModel`, `ExerciseFeedbackModel` are live refs. |
| `Schema/SchemaV2.swift` | `enum SchemaV2: VersionedSchema` — current live form. Models reference live classes from `Models/`. |
| `Schema/MigrationPlan.swift` | `enum AppMigrationPlan: SchemaMigrationPlan` with `migrateV1toV2_addWorkoutId` (Custom Stage). `didMigrate` backfills `ExerciseModel.workoutId` from `workout?.id`; orphans (no relationship) keep `workoutId == nil`. |

Tests:
- `Packages/FitnessStorage/Tests/FitnessStorageTests/Schema/MigrationV1toV2Tests.swift` — exercises the real V1 → V2 container transition (backfill, idempotency, orphan survival).
- `Packages/FitnessStorage/Tests/FitnessStorageTests/Schema/ModelContainerBootstrapTests.swift` — exercises the production bootstrap fallback: writes a pre-T3-shape store (no `VersionedSchema`) and verifies the V1-adoption recovery succeeds, the user data survives with `workoutId` backfilled, and subsequent opens take the direct V2 path.
- `Packages/FitnessStorage/Tests/FitnessStorageTests/WorkoutStorageServiceHealingTests.swift` — pins the four-marker heuristic (`name == "Workout 1"`, `exercises.isEmpty`, `isDefault`, strictly newer than another workout) used by `WorkoutStorageService.healInheritedAutoDefaultIfNeeded`. Covers the canonical inherited-auto-default shape (heal fires) plus four false-positive guards (fresh install, user-created "Workout 1", auto-default with exercises, oldest-empty "Workout 1").
- `Packages/FitnessStorage/Tests/FitnessStorageTests/LegacyMigrationServiceInitOrderingTests.swift` — pins the ordering contract between `DataMigrationService` (legacy JSON → SwiftData import) and `WorkoutStorageService.init`. Plants legacy JSON workouts + UserDefaults blob and asserts (1) prevention path (migration before service init → clean post-migration state with no auto-default) and (2) cure path (forced broken order seeds an auto-default that the next service init heals).

`ExerciseModel.workoutId: UUID?` (Optional!) is the denormalised foreign key replacing the `$0.workout?.id == workoutId` predicate (§14a anti-pattern). Optional because SwiftData's lightweight column-add validates against existing rows before any custom `didMigrate` runs — see ADR-0005 § "Optionalitäts-Regel für neue Properties".

**SPI exposure (T4 + T7)**: `ExerciseModel` and `WorkoutModel` are declared `@_spi(PersistenceUI) public final class` — every stored property and `init` carries the same marker. They become visible to consumers that opt in with `@_spi(PersistenceUI) import FitnessStorage`. **Allowed consumers** (per ADR-0002):

1. `FitnessPersistenceUI` — primary integration surface (all ModelViews + extensions).
2. `FitnessStorage`'s own tests via `@_spi(PersistenceUI) @testable import FitnessStorage`.
3. Specific `@Query`-host views in `FitnessExercise`: `MuscleCategorySelectionView` (T7a + T8a), `MuscleCategoryView` (T7b). These embed ModelViews from `FitnessPersistenceUI` and need direct `@Query<ExerciseModel>` access.

Each new entry in (3) is a deliberate boundary loosening and is review-required. Other feature packages (`FitnessTraining`, `FitnessWorkouts`, `FitnessProfile`, `FitnessAnalytics`) keep their plain `import FitnessStorage` and continue to see only the `public` service API. See [ADR-0002](../../docs/adr/0002-persistence-ui-package.md). Note: in this Xcode/Swift toolchain `@_spi` × `@Model` macro composes cleanly — the macro-bug ADR-0002 anticipated did not materialise.

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
| `LoadLatestFeedbackUseCase` | `Packages/FitnessStorage/.../UseCases/LoadLatestFeedbackUseCase.swift` | `\.loadLatestFeedbackUseCase` | Resolves the most recently saved `ExerciseFeedback` for an exercise via `feedbackStorage.latest(for:)`. Generic look-up; **not** used by `FeedbackViewModel` for prepopulation in the per-session model (the VM filters `feedbackStorage.load(for:)` by its own `sessionId` so a fresh session always starts blank). Available for cross-cutting consumers (reports, analytics summaries, debugging). |

## Shared Components

Located in `Shared/`.

| Component | File | Purpose |
|-----------|------|---------|
| `WorkoutFormSheet` | `View/WorkoutFormSheet.swift` | Full-screen form sheet with title, save, dismiss |
| `WorkoutDropdownView` | `Packages/FitnessUI/Sources/FitnessUI/WorkoutDropdownView.swift` | Workout name dropdown button. Takes `workoutName: String` and optional `titleFont` — no DI, callers pass data from their own storage reference. |
| `WorkoutPickerView` | `Packages/FitnessUI/Sources/FitnessUI/WorkoutPickerView.swift` | Wheel picker for workout selection. Takes `workouts: [Workout]`, `currentWorkout: Workout?`, `onSelect: (Workout) -> Void` — no DI, callers pass data from their own storage reference. |
| `MiniActionMenuView` | `View/MiniActionMenuView.swift` | Small context menu with icon + title rows |
| `CapsuleToggleStyle` | `View/CapsuleToggleStyle.swift` | Reusable toggle style with on/off colors |
| `TrainingSessionComponent` | `View/TrainingSessionComponent.swift` (SPM copy: `Packages/FitnessTraining/.../TrainingSessionComponent.swift`) | Training session UI driven by TrainingCoordinator |
| `TrainingPickerComponent` | `View/TrainingPickerComponent.swift` (SPM copy: `Packages/FitnessTraining/.../TrainingPickerComponent.swift`) | Training picker UI using TrainingCoordinator |
| `TrainingIDs` | `Packages/FitnessUI/Sources/FitnessUI/TrainingIDs.swift` | Accessibility identifiers for training FABs and set rows |
| `UIOverlayState` | `Packages/FitnessUI/Sources/FitnessUI/UIOverlayState.swift` | Global overlay/menu visibility (also still in app `Shared/State/UIOverlayState.swift` until unified) |
| `ActiveSetEditPickerView` | `Packages/FitnessUI/Sources/FitnessUI/ActiveSetEditPickerView.swift` | Reps/weight wheel sheet for active-set edits |
| `FitnessWheelPickerColumn<Value: Hashable, Label: View>` | `Packages/FitnessUI/Sources/FitnessUI/FitnessWheelPickerColumn.swift` | Generic wheel-picker column — title + typed `Binding<Value>` selection + `[Value]` options + custom `@ViewBuilder label`. Keeps locale-sensitive formatting (e.g. weight decimal separator) at label render time so the source of truth stays typed. Used by `ProfileView.BodyMetricsWheelRow` (Weight `Double` / Height `Int` / Age `Int`). `ExerciseWheelPickerRow` predates this and still uses String-tagged Pickers. |
| `OverlaySheetContainer` | `Packages/FitnessUI/Sources/FitnessUI/ExercisePickerSheetChrome.swift` | Reusable overlay sheet with backdrop, grabber, swipe-dismiss, appear animation. Separates content (scrollable), actions (fixed bottom), and overlay (e.g. numpad). All picker sheets use this. Optional `backgroundColor` parameter (default `AppStyle.Color.sheetBackground`) overrides the sheet body fill — used by `FeedbackSheetView` to switch to `AppStyle.Color.black` for stronger contrast with the glass-effect tiles. |
| `ExercisePickerActionButtons` / `exercisePickerSheet` | `Packages/FitnessUI/Sources/FitnessUI/ExercisePickerSheetChrome.swift` | Shared picker sheet chrome (inner styling + action buttons) |
| `RefreshActionButton` | `Packages/FitnessUI/Sources/FitnessUI/RefreshActionButton.swift` | Solid-green pill action button (140×40, `AppStyle.CornerRadius.editPickerViewButton`) used to manually refresh remote data. Mirrors the Save button in `ExercisePickerActionButtons` so the action-bar visual language stays consistent. Default title `"Refresh"`, swaps icon for `ProgressView` while `isLoading`. Used by `TramDeparturesCardView` and the BMI section in `ProfileView`. |
| `MetricChipView` | `Features/Exercise/ExerciseCard/MetricChipView.swift` | Generic chip container with background/stroke |
| `WeightPhaseTileView` | `Features/Exercise/ExerciseCard/WeightPhaseTileView.swift` | Weight/reps phase tile for analytics display |
| `CardBackground` | `Features/Exercise/ExerciseCard/CardBackground.swift` | Card wrapper with `Style` enum (`.glass`, `.gradient(Color)`) |
| `SetTileView` | `Features/Exercise/ExerciseCard/SetTileView.swift` | Completed set display tile (weight/reps) |
| `SetRowChipStyle` | `Features/Exercise/ActiveSet/SimpleActiveSetView.swift` | ViewModifier for set row chips — use `.setRowChipStyle(minWidth:)` |
| `FeedbackSheetComponent` | `Packages/FitnessTraining/.../Feedback/FeedbackSheetComponent.swift` | Zero-size (`Color.clear`) mount point that presents `FeedbackSheetView` via native `.sheet(...)` with **two progressive `.presentationDetents`** — a content-fitted `.height(smallDetentHeight)` and `.large` — plus `.presentationDragIndicator(.visible)` and `.presentationBackground(AppStyle.Color.black)`. **Progressive-disclosure detent**: opens at the small detent (Title + 4 Symptom-Tiles + Hide/Save action bar only); auto-expands to `.large` (animated `.easeInOut(0.25)`) as soon as `viewModel.symptoms` becomes non-empty, and animates back down when all symptoms are deselected. Re-edit case (existing draft / committed entry) opens directly at `.large`. The small detent height is measured at runtime: `FeedbackSheetView` reports the natural pixel height of its initial content via `onInitialContentHeightChange`; the component adds the action-bar height (~84pt) and stores the result in `smallDetentHeight`. A 380pt initial estimate covers the very first frame before measurement settles. **Same presentation pattern as `AnalyticsView`** for the grabber / system look (the exercise-card siblings are now `InactiveCardModelView` / `ActiveCardModelView` / `IdleActiveCardModelView` in `FitnessPersistenceUI`). System-rendered grabber, status bar, and pull-to-dismiss gesture come for free. Instantiates `FeedbackViewModel` lazily per presentation, scoped to the current exercise + the active **`sessionId`** (resolved via `coordinator.currentSessionId(for:)`, falling back to a fresh UUID if no session is active). Pre-selects the body category from the exercise's `MuscleCategoryGroup`. Wires the coordinator's `draftStore` and a `currentFocusedExerciseId` closure into the view model so autosave (in-memory draft) is exercise-scoped and resilient to the user switching exercises while the sheet is closing. Sets `UIOverlayState.isEditingSheetVisible` while visible so the bottom action bar hides — matching `TrainingPickerComponent` and `MuscleCategoryView`. |
| `FeedbackSheetView` | `Packages/FitnessTraining/.../Feedback/FeedbackSheetView.swift` | Post-exercise feedback form rendered as a native `.sheet` with **two progressive detents** (small content-fitted + `.large`, managed by `FeedbackSheetComponent`). Reports its own initial content height via `onInitialContentHeightChange` (measured with a `PreferenceKey` + named coordinate space on the `SymptomChipsView` block) so the small detent always exactly fits Title + 2x2 Symptom-Tiles + bottom breathing room. **Same presentation pattern as `AnalyticsView`** (system grabber + status bar + pull-to-dismiss come for free). Black background via `.presentationBackground` on the sheet. **Progressive disclosure** layout: `ScrollView + LazyVStack` { centered title `"Exercise Feedback"`, **Physical Symptoms** (`SymptomChipsView`, always visible), **Pain** (`PainRegionGrid` — multi-select, only when `.pain` symptom is selected), **Energy level** (`EnergyLevelSlider`, only when ≥1 symptom is selected), **Notes** (single-line `TextField` with `.submitLabel(.done)` + `.onSubmit { isFocused = false }` — same blue-checkmark Return-key dismissal as `ExerciseNamePickerView` ("Edit Title"). The wrapper reserves a 64pt min-height so existing notes still display nicely; only when ≥1 symptom is selected) } + sticky `ExercisePickerActionButtons` (**Hide**/Save) at the safe-area bottom on a flat black background. The left button is labelled **Hide** (not Cancel) because closing the sheet does **not** discard unsaved changes — they remain in the in-memory draft store and reappear on next open. Save is the only action that commits to storage (per-session upsert via `FeedbackStorageService`). The action bar is **hidden while the Notes keyboard is focused** (animated fade, driven by `@FocusState`) so the iOS blue "Done" submit key is the only confirmation affordance during typing; on dismiss-keyboard the bar fades back in for the sheet decision. Mutations to `energyLevel`, `painRegions`, `symptoms` and `note` trigger `viewModel.autosaveDraft()`, which writes the current form state into the coordinator's `ExerciseFeedbackDraftStore` (or clears it when empty). On open, `FeedbackViewModel.prepopulate()` resolves form state in this order: 1) committed record for the **active session** (re-edit case), 2) in-memory draft for this exercise, 3) blank form. **No** fallback to "latest committed feedback for this exercise" — every fresh session starts blank, analytics-style. All English copy. |
| `ExerciseFeedbackDraftStore` | `Packages/FitnessTraining/.../Feedback/ExerciseFeedbackDraftStore.swift` | See *Services* table — included here as a reminder that the feedback sheet, the bottom-bar icon, and the coordinator all observe the same single-slot draft store. |
| `FeedbackEntryIconState` / `FeedbackEntryIconResolver` | `Packages/FitnessTraining/.../Feedback/FeedbackEntryIconState.swift` | Three-state enum (`entry`, `draft`, `done`) used by `BottomActionBarView` to pick how the feedback FAB renders. **Bitmap assets per state** (`feedback_entry`, `feedback_entry_draft`, `feedback_entry_done` shipped in `FitnessApp/Assets.xcassets/` — square 1024×1024, content luminance-bbox centered, **`template-rendering-intent: original`**, two-color hardcoded into the PNG using `AppStyle.Color.painAccent` (`#FF6B3D`) for the plus-cross fill and `AppStyle.Color.greenGlow` (`#3CC8A6`) for the state-badge in the bottom-right). Rendered with `.renderingMode(.original)` in `BottomActionBarView.feedbackIconButton(state:)` so the baked colours come through unchanged, placed over the standard `TrainingGlassEffectCompat.circleGlass()` chrome with a 1pt white-10% stroke. All three states share the solid-orange filled plus-cross identity at **identical pixel coordinates** (bbox `x:233..789 y:234..788`, size 557×555, centered at `(511, 511)` — i.e. exactly on the 1024×1024 canvas centre, normalized `(0.499, 0.499)`, arm thickness 168 px, corner radius 30 px) so the plus does not visually shift when the icon changes state. This canvas-centred layout means `BottomActionBarView.feedbackIconButton(state:)` can render every state through a single uniform `glassCircleIconButton` helper with no per-state geometry compensation. The green badge attached to the bottom-right communicates progress: entry has no badge (and a clean unbroken plus, regenerated from scratch as a perfect rounded-rectangle cross at the matched coordinates), draft has a two-tone pencil inside a **system-yellow** outline circle (thick yellow body and outline ring both in `AppStyle.Color.yellow` `#FFCC00` — luminance-mapped from the original turquoise so the existing shading is preserved — with a prominent yellow-green wood cone tip in `symptomNausea` `#9CCC30` taking ~33% of the pencil length, body-aspect ~1:3 with only slightly rounded corners, oriented diagonally with the tip pointing lower-left — classic "edit" pose, anatomy modeled on a classic pencil silhouette so the cone tip reads clearly even at the 48pt symptom-tile icon size). The draft badge therefore reads as a **fully yellow** "in-progress / pending edit" indicator, while the `done` badge stays turquoise to mark completion — giving the two states an unmistakable hue contrast (yellow=draft, turquoise=done)., done has a green checkmark inside a green outline circle. The two-color split (orange = subject of feedback / pain, green = action / completion) keeps the palette consistent with the Pain symptom chip and the project's bmi-normal / completion accent. `FeedbackEntryIconResolver.state(for:sessionId:draftStore:storage:)` resolves the state with **`done` taking precedence over `draft`**: if a committed entry exists in `feedbackStorage.load(for:)` whose `sessionId` matches the active session, the icon is `done`; otherwise, if a non-empty draft exists for that exercise in `ExerciseFeedbackDraftStore`, the icon is `draft`; otherwise `entry`. Done is scoped per active session — re-starting the same exercise (= new `sessionId`) resets the icon back to `entry` even when a previous session's feedback is still in storage. |
| `Symptom+UI` | `Packages/FitnessTraining/.../Feedback/Symptom+UI.swift` | UI-layer extension that maps `Symptom` (FitnessCore domain enum) to its display tint (`AppStyle.Color.symptomPain` / `symptomDizziness` / `symptomNausea` / `symptomWeakness`). Lives in `FitnessTraining` so the domain layer stays free of any SwiftUI/Color dependency. Consumed by `SymptomTile` (icon + title + selection outline). |
| `EnergyLevelSlider` | `Packages/FitnessTraining/.../Feedback/EnergyLevelSlider.swift` | Custom horizontal 1...5 slider with a **thicker capsule track** (10pt) and a **light-green → dark-green `LinearGradient` fill** (`AppStyle.Color.greenLight` → `AppStyle.Color.green` over `AppStyle.Color.greenDark` background). Composed manually inside a `ZStack` because SwiftUI's stock `Slider` cannot be resized vertically — a `DragGesture(minimumDistance: 0)` snaps to whole integers 1...5. 24pt white circular thumb with a soft drop shadow rides on the gradient. The header row shows `Low` / `High` labels and, once the user has picked a value, an additional right-aligned **percent label** (`20%` / `40%` / `60%` / `80%` / `100%`) so the absolute level is readable at a glance. The numeric "X / 5" indicator and the tick-number row were removed (the thumb position + percent carry that information). Binds directly to `FeedbackViewModel.energyLevel`. Identifier `TrainingIDs.energyLevelSlider`; exposes `accessibilityAdjustableAction` for VoiceOver swipe up/down and `accessibilityValue` ("`<percent>%`"). |
| `SymptomChipsView` | `Packages/FitnessTraining/.../Feedback/SymptomChipsView.swift` | 2-column `LazyVGrid` von **kompakten** `SymptomTile`s (Pain, Dizziness, Nausea, Weakness) im 2x2-Raster. Jeder Tile zeigt einen 48pt-Icon-Kreis (mit 60pt-Glow bei Selektion), UPPERCASE-Titel (`Symptom.displayName`) und einzeiligen Subtitle (`Symptom.description`, z.B. "Acute or sharp discomfort", `.minimumScaleFactor(0.85)` für Dynamic Type). **Symptom-spezifische Akzentfarbe** über `Symptom.iconColor` (`Symptom+UI`): Pain rot/orange (`AppStyle.Color.symptomPain`), Dizziness blau (`symptomDizziness`), Nausea hellgrün (`symptomNausea`), Weakness lila (`symptomWeakness`). Diese Farbe wird für Icon, Selektions-Border, Glow und Title verwendet — `AppStyle.Color.greenGlow` ist nicht mehr hartcodiert. Tile-Hintergrund über `TrainingGlassEffectCompat.rectCard` (Liquid Glass auf iOS 26+, `ultraThinMaterial` sonst); leichte Tönung in der Akzentfarbe wird zusätzlich auf das Glas gelegt. SF-Symbol-Icons: `bolt.fill`, `tornado`, `face.dashed`, `dumbbell.fill`. |
| `PainRegionGrid` | `Packages/FitnessTraining/.../Feedback/PainRegionGrid.swift` | 3-column `LazyVGrid` of `PainRegionTile`s, pre-scoped to the exercise's `BodyCategory`. **Multi-select**: `selectedRegions: Set<BodyRegion>` + `onToggle` — beliebig viele Regionen können gleichzeitig aktiv sein (z. B. Lower back + Obliques). Image-only Tiles (120pt hoch, `scaledToFit`) mit `TrainingGlassEffectCompat.rectCard` als Tile-Hintergrund (Liquid Glass auf iOS 26+, `ultraThinMaterial` sonst); kein Text-Label — der Regions-Name dient nur als `accessibilityLabel` für VoiceOver. Selektion durch grünen Rahmen + weicher Glow-Kreis; Tippen auf ein bereits ausgewähltes Tile entfernt es aus der Auswahl (ersetzt die frühere "None"-Option des Wheel-Pickers). Asset-Name pro Region via `BodyRegion.iconAssetName`; fehlende Assets → leerer Kasten (nur Rahmen, kein Inhalt). |


## Utilities

Located in `Shared/Utilities/`.

| Utility | File | Usage |
|---------|------|-------|
| `WeightFormatter` | `WeightFormatter.swift` | `displayWeight(_:)` — always use for weight display |
| `AnalyticsDateHelper` | `AnalyticsDateHelper.swift` | Month names, unique days, days-in-month for analytics |
| `DateFormatterUtility` | `DateFormatterUtility.swift` | Shared DateFormatter instances (`germanMedium`, `germanMonthYear`, etc.) |
| `WeightOptionsGenerator` | `WeightOptionsGenerator.swift` | Generate weight option arrays for pickers. String variants (`exerciseWeightOptions`, `trainingWeightOptions`) for legacy Picker rows; typed `[Double]` variants (`bodyWeightOptionsKg` + `bodyWeightOptionsKgIntegerOnly`) for the Profile body-metrics wheel (locale-agnostic source of truth; formatting at label render time). Both typed arrays are cached `static let`s so the decimal-toggle in `BodyMetricsWheelRow` never re-allocates or re-filters the 341-element option list. |
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
    case training(exerciseId: UUID, category: MuscleCategoryGroup) // -> TrainingView
}
```

Navigation is managed by `AppRouter` (injected as `@EnvironmentObject`). Use `router.navigate(to:)` to push, `router.pop()` to go back, `router.popToRoot()` to reset, and `router.replaceAll(with:)` for tab switches or deep links. `AppRouter` automatically derives `currentScene: AppCurrentScene` from the navigation stack — do **not** set the current scene manually. Do **not** manipulate `NavigationPath` directly in views.

## AppStyle Tokens

All tokens in `Packages/FitnessUI/Sources/FitnessUI/AppStyle.swift`. When no token exists for a value, add one before using.

### Padding

`horizontal` (18), `screenHorizontal` (15), `card` (16), `titleTop` (8), `titleBottom` (17), `activeCardIconOverflow` (20), `sectionSpacing` (18)

### Layout

`cardHorizontalPadding` (16), `chipHeight` (32), `activeCardContentHeight` (80), `activeCardMaxWidth` (400), `categoryIconSize` (50), `idleCategoryIconSize` (64), `checkmarkSize` (36), `playButtonSize` (36), `playIconSize` (16), `idlePlayButtonSize` (28), `idlePlayIconSize` (12), `idlePlayIconOpticalOffset` (1.5 — optical centering for `play.fill` SF Symbol), `idlePlayRingWidth` (0.75 — hairline metallic ring stroke width on the idle play button), `idlePlayButtonGlowRadius` (16 — blur radius for the mint halo behind the idle play button), `idlePlayButtonGlowSize` (30 — diameter of the mint halo, only marginally larger than `idlePlayButtonSize` so the component's reported bounds stay tight against the visible button; the blur radius creates the halo softness, not the disc size), `idleCardBorderWidth` (1 — stroke width of the outer border around the idle card), `completedBarWidth` (8), `setRowBadgeSize` (26), `analyticsImageSize` (60), `seatIconSize` (22), `analyticsEntryIconSize` (24), `tipIconSize` (16 — tip coaching icon inside the tip box), `tipBoxSize` (32 — side length of the rounded-rect tip button in the idle card), `tipBoxCornerRadius` (8 — corner radius of the tip box), `separatorHeight` (28), `separatorWidth` (0.5 — hairline width of vertical column separators in metric rows), `doneButtonWidth` (80), `doneButtonHeight` (28), `profileCardMinHeight` (100), `profileCardCollapsedMinHeight` (72), `profileWheelHeight` (150), `profileAvatarSize` (80), `numberPadKeySize` (60), `numberPadSpacing` (12), `scrollWheelItemHeight` (60), `scrollWheelVisibleItems` (5), `scrollWheelSnapTolerance` (18), `sheetContentBottomPad` (23), `workoutPickerWidth` (320), `workoutPickerHeight` (220), `workoutPickerWheelHeight` (150), `overlayConfirmButtonSize` (32), `grabberWidth` (36), `grabberHeight` (5), `capsuleToggleWidth` (44), `capsuleToggleHeight` (26), `capsuleToggleThumb` (22), `miniMenuMaxWidth` (320)

### CornerRadius

`card` (16), `bottomBarButton` (12), `editPickerViewButton` (12), `defaultButton` (12), `sheet` (22), `tile` (10), `timerCard` (12), `numberPadKey` (12), `pill` (20), `overlay` (20), `capsuleToggle` (12)

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

`backgroundColor`, `primaryButton`, `exerciseCardBackground`, `idleCardBackground` (#18191B — dedicated dark base surface for the idle exercise card; do **not** swap with `exerciseCardBackground` which stays #232227 for all other cards/tiles), `idleCardSoft` (#1A1B1D — upper-left stop in the idle card surface gradient, slightly lighter than the base for a barely-perceptible sheen), `idleCardDark` (#161719 — lower-right stop in the idle card surface gradient, slightly darker than the base so the card subtly recedes towards its bottom edge), `idleCardBorder` (#2F3033 — visible-but-unobtrusive stroke around the idle card), `chipsBackground`, `white`, `black`, `yellow`, `gray`, `grayDark`, `greenBlack`, `greenDark`, `green`, `greenLight`, `greenMint` (#80C2B4), `greenFrost` (#AACDC6), `greenGlow`, `idleTitle` (#F2F2F2 — soft off-white title text on the idle card), `idleMetricLabel` (#A7AAA9 — secondary metric labels: "Weight"/"Seat"/"Progress", `kg` unit suffix, expand chevron), `idleMetricValue` (#B7DCC5 — primary metric values + accent glyphs: weight number, seat arrows, progress icon, tip icon+text, play triangle), `idlePlayRingBase` (#6B6F6E — hairline metallic ring stroke around the idle play button), `idlePlayRingGlow` (alias to `#B7DCC5.opacity(0.18)` — soft mint outer halo around the idle play button). The play-button **center is filled with `idleCardBackground`** so it reads as a hole punched into the card surface, `sheetBackground`, `sheetInputBackground`, `metricChipBackground`, `progressTrack`, `numberPadGray`, `trainingAccent`, `inProgressGold`, `profileCardBackground`, `bmiUnderweight`, `bmiNormal`, `bmiOverweight`, `bmiObese`, `painAccent` (red/orange — also used as the alias for `symptomPain`), `symptomPain`, `symptomDizziness` (blue), `symptomNausea` (light green), `symptomWeakness` (purple) — the symptom colors are the canonical tints for each `Symptom` case in the feedback sheet (`SymptomTile` consumes them via `Symptom.iconColor` in `Symptom+UI`)

### Opacity

`overlayBackdrop` (0.55), `subtleBackground` (0.06), `subtleStroke` (0.15), `grabberHandle` (0.35), `disabledElement` (0.3), `fadedOverlay` (0.4), `idleIconGlow` (0.3 — opacity for the dark glow circle behind the idle category icon), `idlePlayButtonGlow` (0.25 — opacity for the mint halo behind the idle play button), `numberPadInactive` (0.5), `numberPadFade` (0.2)

### Shadow

`cardColor` (black 0.2), `cardRadius` (5), `cardY` (2), `overlayRadius` (20), `overlayY` (10)

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
