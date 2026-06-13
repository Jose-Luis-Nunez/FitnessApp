# 0001 — SwiftData @Model as the Single Source of Truth in the UI

* Status: accepted
* Date: 2026-04-19
* Deciders: jose.nunez

## Context

The app went through two refactor waves for cross-layer state sync that did not
solve the sync problem:

- **Refactor 1**: per-coordinator `withObservationTracking` loops +
  `restartCoordinatorObservations` — fragile, many explicit subscriptions
- **Refactor 2** (commit `d1e5e746`): a consolidated `changeVersion: Int`
  counter with polling loops in every ViewModel — masks save failures,
  does not replace domain events

Both left two active bugs behind:
1. `TrainingView` shows an "idle" card without a play button after an exercise
   finish (visually stale, only refreshes on re-mount).
2. `MuscleCategorySelectionView` updates the "X of Y" category tiles only when
   the workout view is opened — not immediately after an exercise finish.

The structural root cause was **four parallel copies of the same `Exercise` entity**:

- `ExerciseStorageService` holds `[ExerciseModel]` (SwiftData)
- `ExerciseManagementService` passes domain operations through
- `MuscleCategorySelectionViewModel.cardViewModels[UUID]` held one
  `ExerciseCardViewModel` per ID with its own `Exercise` copy
- `TrainingView.@State private var cardViewModel` held yet another copy

Each of these sources had to be synchronized manually on a mutation.
`syncExercise(...)`, `refreshExercises()`, and `changeVersion &+= 1` were all
symptom workarounds for the same structural multi-source. The last two snapshot
copies were removed with T8d (pilot migration in `MuscleCategoryView`
+ `MuscleCategorySelectionView`) and T8d/Training (migration of the
`TrainingView` path).

## Options

- **A**: Status quo — keep evolving the `Int` counter, add more `syncExercise` calls
- **B**: Unidirectional data flow / Redux pattern (TCA or similar) — its own store, reducers, effects
- **C**: SwiftData `@Model` directly as the UI SoT, `@Bindable`/`@Query` in views
- **D**: CoreData with an `NSFetchedResultsController` wrapper

### Evaluation

**A** is empirically disproven. Two refactor waves did not solve the sync problem — the bug class is structural, not implementation-related.

**B (TCA)** is a **valid** architecture and solves the bug classes by construction (unidirectional flow, scoped stores, deterministic reducer tests). It was rejected for one reason: **platform direction**. Apple's entire 2025/26 SwiftUI strategy (`@Observable`, `@Model`, `@Query`, `@Bindable`, the `Observation` framework) aims to deliver the **same effect** as a unidirectional store **without an external dependency**. Pointfree (TCA's creators) themselves are migrating TCA's internal architecture onto `@Observable`. Anyone starting fresh today bets either on TCA (against the platform direction, with additional persistence boilerplate because SwiftData does not fit into TCA's state model) **or** on `@Model`+`@Query` (with the platform, zero persistence boilerplate).

**D (CoreData + FRC)** would be a step backward — `NSFetchedResultsController` is a UIKit pattern with imperative updates and does not fit SwiftUI's declarative model.

**C** is the first-party platform answer to exactly the problem we want to solve. It eliminates the bug classes by construction (one `id` → one source), removes more code than it adds (T8 cleanup), and positions the codebase on the path Apple keeps developing.

## Decision

**Option C**: SwiftData `@Model` is the single source of truth in the UI.

UI components consume `@Model` instances directly:

- **Detail views** hold a concrete `@Model` reference via `@Bindable var model: ExerciseModel`
- **List/collection views** bind via `@Query(filter: ...) var items: [ExerciseModel]`
- **Mutations** happen on the `@Model` instance itself (`model.isCompleted = true`)
- **Persistence** via `try? context.save()` in the same MainActor tick — Apple's
  automatic observation propagation updates all active `@Query`s and
  `@Bindable` views immediately.

### Scope

- The plan stays **`@MainActor`-only**. No `@ModelActor`/background mutation in
  this refactor — mitigation of the known background-context update leak
  (see Stack Overflow Jan 2026, Apple Forums Apr 2025).
- Exactly **one** `ModelContext` for the UI path (the `ModelContainer`'s `mainContext`).
- `struct Exercise` (in `FitnessCore`) stays for non-UI concerns:
  analytics snapshots, cross-package DTOs, pure logic tests, persistence helpers
  outside the `@Model` lifecycle.
  **New UI may only hold `@Model` references.** No `@State` with an
  `Exercise` struct.
  The previously deliberate exception in `TrainingView.swift` (snapshot
  `ExerciseCardViewModel`) was removed with the T8d cleanup (migration: legacy
  card stack → model card stack): `TrainingView` now resolves its
  `exerciseId: UUID` via `@Query<ExerciseModel>` and renders
  `ExerciseCardModelView` directly.
  Coordinator APIs that still expect `Exercise` (DTO)
  (`TrainingCoordinator.startTraining(for:)`,
  `TrainingActionBarComponent`) are bridged with `model.toDomain()` at the
  respective call sites. As a result there is no longer any UI view that holds an
  `Exercise` snapshot — the "stale UI after mutation" bug class is excluded
  app-wide by construction.

### Non-Goals

- No CloudKit sync in this phase (prepare for it via ADR-0002, but do not enable it).
- No reduction of existing domain tests that work with `struct Exercise`.
- No immediate migration of all views — pilot migration via T5/T6/T7,
  legacy cleanup in T8.

## Consequences

### Positive

- The "stale snapshot" and "VM cache desynchronized" bug classes cannot exist
  by construction — there is only one source per `id`.
- Massively less code: `changeVersion`, `refreshExercises`, `syncExercise`,
  polling loops, and VM caches keyed by UUID are removed entirely (T8).
- SwiftUI-native, idiomatic — new team members find familiar patterns.
- Tests can use an in-memory `ModelContainer` and reproduce exactly the
  production behavior (see the T2 RED tests).

### Negative

- Three new bug classes take the place of the old two:
  - **Predicate bug** (`?.` / `!.` chains, `persistentModelID`) — mitigation:
    T0e skill §14 + T3 schema migration (`workoutId: UUID`)
  - **Multi-context gap** — mitigation: single `ModelContext` (see Scope)
  - **View identity race** with dynamic `@Query` filters — mitigation: `.id()`
    on parent views (see T0e skill §14d)
- `@Model` lifecycle and SwiftData quirks (predicate format, `@Attribute(.unique)`,
  `.modelContainer` setup) become a mandatory competency on the team.

### Neutral

- `struct Exercise` (DTO) and `@Model class ExerciseModel` (persistence +
  UI source) coexist during and after the refactor. The DTO boundary is
  deliberate and documented.
- CloudKit possible later. But it needs an explicit conflict strategy and
  CRDT considerations — a separate ADR when we get there.

## When this decision must be re-evaluated

This ADR is not set in stone. Reopen it if **any** of the following triggers occurs:

- **Complex asynchronous flows**: real-time multi-device editing, long-running
  HealthKit re-auth state machines, Apple Watch live sync with conflict
  resolution. TCA's deterministic `TestStore` tests are objectively better here
  than `@Model`+`ModelContext` tests.
- **Cross-cutting effects orchestration**: when five+ features need to
  coordinate asynchronous effects simultaneously (telemetry, logging, analytics,
  sync, cache invalidation), an explicit effects layer (TCA) becomes clearer
  than scattered `Task { ... }` calls.
- **Apple deprecates/stagnates SwiftData**: very unlikely (Apple has invested
  yearly since iOS 17), but if so — migrate to TCA or
  GRDB+Sharing toolkit as an alternative.
- **Predicate complexity explodes**: if our `@Query` filters regularly need
  joins across 3+ models and SwiftData predicates cannot express them, a
  repository layer with domain queries (à la Clean Architecture) is the better
  answer — TCA is one vehicle for that, but not a necessity.

Trigger occurred → write ADR-0004 (migration to TCA), do not introduce it
silently. A parallel stack is fatal.

## References

- ADR-0002 (FitnessPersistenceUI as the layer for SwiftData UI code)
- ADR-0003 (Coordinator session contract — who holds what during training)
- Plan files: [`.cursor/plans/observable-models-sot/`](../../.cursor/plans/observable-models-sot/)
  (T0–T8 incremental tasks, README.md as the index)
- T0a `ui-state-sync-enforcement.mdc` (forbids the old counter pattern from now on)
- T0e skill §14 (predicate anti-patterns as a reviewer obligation)
- Apple `@Query`: <https://developer.apple.com/documentation/swiftdata/query>
- Apple `@Model`: <https://developer.apple.com/documentation/swiftdata/model()>
