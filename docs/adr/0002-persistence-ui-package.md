# 0002 — FitnessPersistenceUI Package as the single SwiftData UI location

* Status: accepted
* Date: 2026-04-19
* Deciders: jose.nunez

## Context

ADR-0001 establishes SwiftData `@Model` as the single source of truth in the UI.
Consequence: somewhere `import SwiftData` together with `@Query`/`@Bindable` code
has to live. The question is: in which module.

Today's reality:

- `ExerciseModel`, `WorkoutModel`, etc. are `internal final class` in
  `FitnessStorage` — deliberately non-public to protect the schema surface.
- The naive variant "@Query in `FitnessExercise`" does not compile: cross-package
  `internal` access to `ExerciseModel` is not allowed.
- The variant "make all models `public`" opens the `FitnessStorage` API
  permanently. Every schema change becomes a breaking change for all consumers,
  including test targets.
- The variant "move all SwiftData views into the app target" moves UI code
  back into the monolith and undermines the SPM modularization.

## Options

Four real options — each with a different protection strength against "every
feature package reaches raw into the model":

- **A**: Make `ExerciseModel` (and co.) `public`, no additional protection
  (trust + code review).
- **B**: Make them `public` + a SwiftLint custom rule that blocks `import FitnessStorage`
  from feature packages.
- **C**: A new SPM package `FitnessPersistenceUI` with `@_spi(PersistenceUI)`
  as a compiler-enforced access marker on the `@Model` classes.
- **D**: Keep the `internal` models, a new package + a `public Repository` layer
  in `FitnessStorage` that delivers `@Bindable`-capable wrappers (adapter pattern).

### Evaluation

**A** is out. The past shows: without mechanical protection, features
reach directly in anyway, sync anti-patterns come back. That is exactly what we
do not want to reproduce.

**B** (lint rule) is medium-strong: `// swiftlint:disable next` and the protection
is bypassed. Lint runs only in CI and in the editor — no compiler hard lock. For
a 1-person team still acceptable, in larger settings the temptation
"disable just this once, it'll be fine" is too great.

**D** (repository + wrapper) sounds the cleanest — `internal` is the strongest
possible protection guarantee. **Rejected because it defeats the platform**:
SwiftData's `@Query` and `@Bindable` need the concrete `@Model` type.
Wrappers build an indirection layer that reintroduces exactly the boilerplate
whose avoidance is the whole point of SwiftData (`@Query<Model>`
directly in the view, automatic property-granular invalidation, two-way binding).
We would lose the platform advantages just to follow a syntax policy.

**C** is the best solution. `@_spi(SPIName)` is:

1. **Compiler-enforced** — without `@_spi(PersistenceUI) import FitnessStorage`
   the API is invisible to other modules. A stronger guarantee than lint.
2. **An Apple first-party pattern** — Apple itself uses `@_spi` in production in
   `swift-package-manager`, `swift-syntax`, `swift-collections`,
   `swift-foundation`. WWDC sessions explicitly recommend it for
   "module-internal but cross-module" APIs. Stable since Swift 5.3.
3. **PR-review-visible** — every violation must explicitly write
   `@_spi(PersistenceUI) import FitnessStorage`. That is unmissable in the
   diff, and our reviewer subagent can check the pattern automatically
   (a future skill item).
4. **Platform-conformant** — `@Query`, `@Bindable`, automatic SwiftData
   invalidation keep working unchanged. We lose no SwiftData
   functionality.

The `_` in `@_spi` is a syntax policy (marks "not in the official
language book"), not a stability risk. If `@_spi` is ever deprecated,
the migration is trivial: `s/@_spi(PersistenceUI)//g` on the imports +
change the visibility of the models from `@_spi(PersistenceUI) public` to `public`.
Lock-in is low, protection strength high.

## Decision

**Option C**: A new package `FitnessPersistenceUI` with `@_spi(PersistenceUI)`
as an access marker for the `@Model` classes from `FitnessStorage`.

### Package spec

- **Depends on**:
  - `FitnessStorage` — for the `@Model` classes, controlled via the `@_spi(PersistenceUI)`
    marker instead of plain `public`. This keeps access explicitly documented.
  - `FitnessCore` — for enums (e.g. `MuscleCategoryGroup`), DTOs (`Exercise` as a
    boundary type where needed), domain helpers
- **Imports**: `SwiftData`, `SwiftUI`
- **Exports** (state after T5–T8d):
  - `ExerciseCardModelView` — a variant-resolver container on `@Bindable ExerciseModel`
  - `ActiveCardModelView`, `IdleActiveCardModelView`, `InactiveCardModelView`
    — variant-specific card views (all `@_spi(PersistenceUI) public`)
  - `CategoryTileModelView` — `@Query<ExerciseModel>` with `#Predicate` on
    `workoutId` + `category`
  - `ExerciseModel+UI` convenience properties (`hasWeight`, `displayIconName`,
    `categoryGroup`, `iconAlignment`)
  - `enum FitnessPersistenceUI { static let moduleVersion }` as a non-SPI
    public surface
  - **Not shipped**: the `TrainingModelView` wrapper — see the T8b deferral.

### Remaining responsibilities

- `FitnessExercise` stays **primarily** DTO-oriented: `struct Exercise`, view logic
  that gets by without a SwiftData import. Concrete views that serve as a `@Query` host for
  `FitnessPersistenceUI` ModelViews (`MuscleCategorySelectionView`,
  `MuscleCategoryView` since T7a/T7b/T8a) may import `@_spi(PersistenceUI) import
  FitnessPersistenceUI` **and** `@_spi(PersistenceUI) import FitnessStorage`.
  These locations are deliberate boundary softenings, justified in the
  code comment + PR review, not discipline violations.
- `FitnessStorage` exposes its `@Model` classes via `@_spi(PersistenceUI)
  public final class`. Consumers are: (a) `FitnessPersistenceUI` as the primary
  integration layer, (b) `FitnessStorage`'s own tests (`@_spi(PersistenceUI)
  @testable import`), (c) **occasionally** feature views in `FitnessExercise` that
  serve as a `@Query` host for ModelViews from (a). Every new location in (c) is
  review-mandatory.

## Consequences

### Positive

- A clear architecture layer for SwiftData UI code. A single location for
  future topics such as CloudKit migration, conflict resolution, custom
  observation setups, ModelContainer configuration.
- The `FitnessStorage` API stays narrow — schema changes stay internal,
  break nothing in `FitnessExercise` or other DTO consumers.
- Tests can use an in-memory `ModelContainer` without pulling in external
  helper packages.
- The CloudKit future has a known home for `CKSyncEngine` integration
  and conflict-resolution logic.

### Negative

- An additional SPM package marginally increases the build matrix.
- `FitnessExercise` (with `ExerciseCardView` on `struct Exercise`) and
  `FitnessPersistenceUI` (with `ExerciseCardModelView` on `@Bindable
  ExerciseModel`) have parallel card/tile views. In the Home/MuscleCategory
  subtree the migration is complete with T7a/T7b/T8a/T8c/T8d — there
  only `FitnessPersistenceUI` renders. **`TrainingView` (T8b)
  stays deliberately on the legacy `ExerciseCardContainerView` track**, since
  its lifecycle structurally excludes the Bug-1 trigger (the view navigates
  away before `coordinator.finishExercise()` could trigger a UI flip).
  Resumed on a user bug report in the training detail or as a cleanup sprint.

### Neutral

- The app target now depends on 7 instead of 6 packages — negligible.
- `@_spi(PersistenceUI)` is **not** sandbox-like single-consumer. The marker
  forces every importer into an explicit, diff-visible opt-in gesture
  — that is the actual protective effect. Allowed consumers:
  - `FitnessPersistenceUI` (the primary integration layer)
  - `FitnessStorage`'s own tests (`@_spi(PersistenceUI) @testable import`)
  - Specific views in `FitnessExercise` that serve as a `@Query` host for
    ModelViews from `FitnessPersistenceUI` (T7a/T7b/T8a:
    `MuscleCategorySelectionView`, `MuscleCategoryView`)

  Every new importer in `FitnessExercise` (or another feature package)
  is a deliberate boundary softening and requires justification in code review.
  PR diffs show the marker explicitly; a reviewer can see the addition
  immediately.

### Lock-in / exit strategy

`@_spi` has been stable since Swift 5.3 and is used by Apple itself. Should
it ever be deprecated:

- The migration is mechanical: `@_spi(PersistenceUI) public ...` →  `public ...`
- Protection switches from compiler to lint (option B above) — a downgrade but
  not a blocker.
- Effort: hours, not days. Risk: low.

## References

- ADR-0001 (explains why `@Model` in the UI)
- ADR-0003 (coordinator contract — the coordinator stays in `FitnessTraining`,
  consumes no `@Model` classes directly)
- T4 (package skeleton + workspace integration)
- T5 (pilot `ExerciseCardModelView`)
- T6 (pilot `CategoryTileModelView`)
- T7 (incremental migration: T7-0 cycle break, T7a tile-live, T7b card-live)
- T8 (cleanup: T8a list-mode live, T8c routing live, T8d dead-code sweep; T8b TrainingView deferred)
- Swift `@_spi` doc: <https://github.com/apple/swift/blob/main/docs/ReferenceGuides/UnderscoredAttributes.md#_spi>
