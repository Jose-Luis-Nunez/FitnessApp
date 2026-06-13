# 0008 — Friends Comparison: isolated JSON-blob storage + dedicated module

* Status: accepted
* Date: 2026-06-13
* Deciders: jose.nunez

## Context

The Friends feature lets a user import a workout buddy's exported training data
(the existing `WorkoutShareEnvelope` JSON) and compare it side-by-side against
their own current workout (category counts, training-days-this-month, total
exercises, matched exercise pairs).

This introduces structural changes that cross package and persistence
boundaries and therefore require a recorded decision:

- A **new persisted entity** (`FriendModel`) added to the SwiftData store.
- **New Factory container registrations** in `StorageContainer.swift`
  (`friendStorage`, `importFriendUseCase`, `loadFriendComparisonUseCase`) — the
  trigger the `adr-required` hook fired on (`container-change`).
- A **new SPM module** (`FitnessFriends`) for the UI layer.
- A **schema version bump** (`SchemaV2` → `SchemaV3`).

The core tension is **how to persist a friend's training data**. A friend's
data is a full workout graph (workout + exercises + analytics), structurally
identical to the user's own. Two failure modes must be avoided:

1. **Query leakage** — friend exercises must never appear in the user's own
   `loadForWorkout(workoutId:category:)` / analytics queries. The existing
   exercise queries filter by `workoutId`; a friend's exercises carry their
   own ids and could collide or pollute if stored in the same tables.
2. **Migration cost** — every future schema change to the workout graph would
   otherwise have to migrate friend rows too, doubling migration surface for
   data that is read-only and disposable (re-import replaces it).

## Options

- **A — Normalised**: persist friend workouts/exercises/analytics into the
  existing `WorkoutModel`/`ExerciseModel`/`AnalyticsEntryModel` tables, flagged
  with an `isFriend` discriminator (or a separate owner id).
- **B — Parallel typed tables**: dedicated `FriendWorkoutModel` /
  `FriendExerciseModel` / … mirroring the workout graph one-to-one.
- **C — Isolated JSON blob**: a single `FriendModel` storing the canonical
  `WorkoutShareEnvelope` JSON (`envelopeJSON: String`) plus a few extracted
  scalar fields (`name`, `addedAt`, `workoutName`) for list rendering. The blob
  is decoded on demand by `LoadFriendComparisonUseCase`; metrics are computed
  in-memory by the stateless `FriendMetricsCalculator`. Re-import = replace the
  blob in place (keyed by normalised name).

### Evaluation

**A** reintroduces exactly failure mode (1): friend exercises live in the same
tables the user's queries scan, separated only by a discriminator that every
existing and future query must remember to apply. One forgotten predicate =
friend data leaking into the user's training screen. Also inflates every
workout-graph migration with friend rows.

**B** avoids the leak but is heavy: 3+ new `@Model` types, their relationships,
and a migration + snapshot obligation (ADR-0005) for each on every future
change — all to store data that is read-only and thrown away on re-import. The
comparison logic also doesn't need queryable friend tables; it reads the whole
friend dataset at once.

**C** keeps friend data **physically incapable** of entering the workout-graph
queries (no shared tables, no relationships into the graph). The envelope is
already the canonical transport format, so storing it verbatim avoids a
lossy model-to-model mapping. Comparison reads the blob once and computes
in-memory — no queries needed. The cost is that friend data is not itself
queryable, which is acceptable: it is only ever read whole, per selected
friend.

## Decision

**Option C.** Persist each friend as a single isolated `FriendModel`
(`@_spi(PersistenceUI) @Model`) holding the `WorkoutShareEnvelope` JSON blob;
**no SwiftData relationships into the workout/exercise graph**. Scope and
non-goals:

- `FriendModel` is **upsert-by-normalised-name** (lowercased, trimmed) — re-import
  replaces the blob; no friend history/versioning is kept.
- `SchemaV3` is **additive only** (adds `FriendModel`); the V2→V3 stage is
  `lightweight` per the mechanics established in **ADR-0005**, with a real
  container-transition test (`MigrationV2toV3Tests`).
- The **`FitnessFriends`** package owns only the UI layer (`FriendsSection`,
  view models, sheets, comparison views). Domain types (`Friend`,
  `FriendStoring`, `FriendComparison*`, `FriendMetricsCalculator`) live in
  `FitnessCore`; storage (`FriendStorageService`, `ImportFriendUseCase`,
  `LoadFriendComparisonUseCase`) lives in `FitnessStorage` — same layering as
  every other feature.
- DI follows the project convention: constructor injection with `Container.shared`
  Factory defaults; protocols (`FriendStoring`) in `FitnessCore`.

Non-goals: friend data is not synced, not queryable, not historised, and not
exported. Friend UI copy is English (the app's users are English-speaking).

## Consequences

### Positive
- Friend data **cannot leak** into the user's workout/exercise/analytics queries
  — the isolation is structural, not convention-based.
- Future workout-graph schema changes incur **zero** friend-migration cost.
- Re-import is a trivial in-place blob replace; no orphan cleanup.
- Comparison logic is a pure, fully unit-tested function over decoded domain
  objects (`FriendMetricsCalculator`), independent of persistence.

### Negative
- Friend data is **opaque to SQL** — no "find all friends who do bench press".
  Accepted: the feature never needs cross-friend queries.
- The envelope is decoded on every comparison load. Cheap (one friend, in-memory)
  and avoids a stale denormalised copy.
- If `WorkoutShareEnvelope`'s shape changes incompatibly, stored blobs need a
  decode-tolerance path (same lesson as the legacy analytics-decode bug fixed in
  this changeset: never `try?`-swallow a decode failure).

### Neutral
- Adds one schema version (V3) and one package (`FitnessFriends`) to the build.
- `ModelContainerBootstrap` gained a quarantine-restore step in the same
  changeset; that extends the recovery strategy of ADR-0005 and is documented
  on the type itself rather than here.

## References

- ADR-0001 (@Model as UI source of truth)
- ADR-0002 (FitnessPersistenceUI / `@_spi(PersistenceUI)` access rules)
- ADR-0005 (Schema-migration strategy — V2→V3 follows its lightweight-stage mechanics)
- `Packages/FitnessStorage/.../Models/FriendModel.swift`,
  `FriendStorageService.swift`, `Schema/SchemaV3.swift`
- `Packages/FitnessCore/.../FriendMetricsCalculator.swift`, `FriendStoring.swift`
- `Packages/FitnessFriends/` (UI module)
