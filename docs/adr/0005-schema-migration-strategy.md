# 0005 — SwiftData Schema Migration Strategy (VersionedSchema + MigrationPlan)

* Status: accepted
* Date: 2026-04-19
* Deciders: jose.nunez

## Context

To date the app has **no versioned schema**. The `ModelContainer` is
instantiated in `Packages/FitnessStorage/.../StorageContainer.swift` from a flat
`Schema([WorkoutModel.self, ExerciseModel.self, ...])`. In this case Apple's
SwiftData performs implicit "lightweight migrations" as long as changes are
backward compatible (adding a property with a default, a new entity, removing an
optional property). For non-trivial changes (renaming a property, changing a
type, restructuring a relationship, backfilling data) SwiftData throws at
container bootstrap at runtime — that is, a **crash at app start after an
update**.

Concrete trigger: **T3** adds a new property `workoutId: UUID?` on
`ExerciseModel` and must backfill existing entries
(each `ExerciseModel.workout?.id` → its own `workoutId` slot). This is the
**first** schema change that is not trivially backward compatible —
from here on we need an official, mechanical migration strategy.

If the strategy is not defined now, we risk:

1. **Inconsistent migration approaches** — every future schema change picks
   its own pattern (custom in container bootstrap, ad-hoc backfill code,
   imperative "read old → write new", …). Reinvented per change.
2. **Crashes after an app update** — the user is on schema version N, the app
   ships schema version N+1 without a migration plan, container init throws → the
   app no longer starts.
3. **Data loss** — a naive "add a property, use the default, ignore the old
   relationship" migration silently loses old relationship data.
4. **Untestable migrations** — without explicit `VersionedSchema` stages there is
   nothing that can be reproduced in a test with a controlled before/after state.

## Options

- **A**: Keep the status quo — flat `Schema([...])`, keep trusting implicit
  lightweight migration, write custom backfill code in the
  `StorageContainer` init for T3.
- **B**: Introduce `VersionedSchema` + `SchemaMigrationPlan` with `lightweight`
  stages, but keep doing custom migrations ad hoc without a fixed pattern.
- **C**: `VersionedSchema` + `SchemaMigrationPlan` with a documented pattern:
  - Each schema version is an `enum SchemaVN: VersionedSchema` namespace
  - Each schema version is its own file (`Packages/FitnessStorage/.../Schema/SchemaV1.swift`,
    `SchemaV2.swift`, …)
  - The migration plan is its own file (`Packages/FitnessStorage/.../Schema/MigrationPlan.swift`)
  - Custom stages are named functions (`migrateV1toV2_addWorkoutId(...)`)
    with a dedicated test (`SchemaV1toV2MigrationTests.swift`)
- **D**: Our own migration engine in domain code (read-old-storage, write-new-storage)
  outside SwiftData's migration API — maximum control but we reinvent
  the wheel.

### Evaluation

**A** is out because T3 is a non-trivial migration (backfill from an
existing relationship). Implicit lightweight migration cannot do that;
ad-hoc code in the container bootstrap is not testable and lays down the same
path again next time.

**B** solves T3 but leaves the consistency hole. Six schema versions
later the team has six different migration styles.

**D** discards SwiftData's built-in mechanics. Double the complexity without
gain — SwiftData's `MigrationPlan` API is designed for exactly this use case
and is developed further by Apple.

**C** is the first-party platform answer plus a documented pattern for
file layout and test obligation. Each migration is its own file, each has
its own test, the container init stays clean, new schema versions
follow the same path mechanically.

## Decision

**Option C**: `VersionedSchema` + `SchemaMigrationPlan` with a fixed file
layout and a test obligation per migration stage.

### File layout (binding)

```
Packages/FitnessStorage/Sources/FitnessStorage/
├── Models/                     # Live definitions (= latest schema
│   ├── WorkoutModel.swift      # version), app code imports from here
│   ├── ExerciseModel.swift
│   └── ...
├── Schema/
│   ├── SchemaV1.swift          # enum SchemaV1: VersionedSchema {
│   │                           #   nested @Model class for each class
│   │                           #   that has changed SINCE then;
│   │                           #   models = [Snapshot..., LiveRef...]
│   │                           # }
│   ├── SchemaV2.swift          # analogous for V2
│   ├── SchemaVN.swift          # latest version: only live refs in models
│   │                           # (no snapshots, because = current state)
│   └── MigrationPlan.swift     # enum AppMigrationPlan: SchemaMigrationPlan
└── StorageContainer.swift      # uses AppMigrationPlan + SchemaVN.self
```

### Pattern per schema version

Each `SchemaVN.swift` contains:

1. `enum SchemaVN: VersionedSchema` with `static var versionIdentifier`
2. `static var models: [any PersistentModel.Type]` — the list of all
   persisted `@Model` classes as they look in **this** schema version.

Which of those classes need their **own snapshot definition** is governed by
the snapshot obligation (see the next section).

### Snapshot obligation (hybrid rule)

A `@Model` class must be written as a snapshot copy under
`SchemaVN.<Class>` **only when its persisted form**
has **changed** in a later schema version (property added
non-optional, property removed, type changed, relationship restructured,
index/unique constraint changed).

As long as a class stays **identical** across multiple schema versions,
`SchemaV{N-1}.models` and `SchemaVN.models` reference the same
live type from `Models/`.

**Mechanics on the next schema change**:

1. Identify the class(es) to be changed.
2. **Snapshot their CURRENT (= V{N}) form** under
   `Schema/SchemaV{N}.swift` as a nested `@Model class`. Content =
   a 1:1 copy of `Models/<Class>.swift` *before* you change it.
3. Edit `Models/<Class>.swift` to the new form (= `V{N+1}`).
4. Create `Schema/SchemaV{N+1}.swift`. `models:` references the
   new live classes plus all unchanged live classes.
5. `SchemaV{N}.models:` replaces the entry of the changed class with
   the snapshot (`SchemaV{N}.<Class>.self`); unchanged classes
   stay live refs.
6. Extend `MigrationPlan.swift` with `migrateV{N}toV{N+1}_<intent>`.
7. Write a test (see test obligation).

**Relationship-closure rule**: A `@Relationship` (inverse or direct)
always references a concrete Swift type. If the changed
class `Z` has a relationship from class `A` (`A` holds `[Z]` or
`A: \Z` inverse), then in V_old and V_new **two distinct**
Swift types are active for `Z`. SwiftData cannot register a live class `A`
on two types for `Z` at the same time — so **`A`
must also be snapshotted**, even if `A` itself stays
field-identical. The snapshot is then a 1:1 copy of the live class, whose
sole function is to point at the V_old `Z` type in V_old.

Pure FK fields (`var fooId: UUID`) are **not** a relationship in
the sense of this rule and do not trigger the closure snapshot.

Follow this rule recursively until no class cluster has any more connections
across the "changed" set. Other `@Model` classes without
a relationship in this cluster stay live refs.

### Rationale for the hybrid rule

The strict "snapshot every class of every version" variant is
correct but expensive: with 5 models and 4 migration steps it yields
20 snapshot definitions, 15 of which are clones of identical code. The
"all classes are live refs in all versions" variant is cheap
but breaks the migration test (you cannot create V1 data with the V2 form,
so you also cannot test-migrate it).

The hybrid rule snapshots **only the actually changed classes**.
Diff cost = cost of change. Reviewability is preserved
("Which class changed?" = "which one has a snapshot in
this commit?"), and migration tests stay writable because V_old
and V_new are two distinct Swift types for the changed class.

Apple's WWDC23 SampleTrips follows exactly this hybrid (Trip is
snapshotted because Trip changes; LivingAccommodation and
BucketListItem stay live refs between V1/V2 because they are unchanged).

### Pattern per migration

`MigrationPlan.swift` contains:

```swift
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self /* ..., SchemaVN.self */]
    }
    static var stages: [MigrationStage] {
        [migrateV1toV2_addWorkoutId /*, ... */]
    }

    static let migrateV1toV2_addWorkoutId = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            // Backfill: each ExerciseModel.workoutId = workout?.id
            // (orphans stay nil, overwritten on the next save)
        }
    )
}
```

Each `MigrationStage` is a **named** static property
(`migrateVNtoVNplus1_<intent>`). Anonymous in the array works too, but it hurts
readability and makes referencing it from tests cumbersome.

### Optionality rule for new properties (lightweight limit)

**Rule**: A new property that does not exist in `V_old` and is added in
`V_new` **must be declared as optional** (`var foo: Bar?`),
even if it semantically may never be `nil`.

**Rationale (backed by Apple docs)**:

SwiftData performs an implicit lightweight step before every custom
`MigrationStage`. It augments the persisted tables with the
new column **before** `willMigrate`/`didMigrate` runs. This step
validates the column against the new schema and fails with
`Validation error missing attribute values on mandatory destination
attribute` if the column is non-optional and no value exists for existing
rows. The `init` default does not apply here — that only applies
to **newly inserted** objects, not to the migration of existing rows.

Documented by:

- Apple Developer Forum thread "SwiftData Migration Error: Missing
  Attribute Values" — an Apple engineer's answer recommends optional + a custom
  stage for backfill: <https://developer.apple.com/forums/thread/746577>
- Apple Developer Forum thread "Migrating schemas in SwiftData":
  <https://developer.apple.com/forums/thread/764236>

**Alternatives that were evaluated and rejected**:

| Variant | Rejected because |
|---|---|
| Property non-optional + `init` default | Crash on the first container open after update (init does not apply during migration) |
| 3-schema chain V1 → V1.5 (optional) → V2 (non-optional) | Double the snapshot/stage/test effort per FK field; the benefit is only cosmetic (`UUID` instead of `UUID?` in the live code) |
| Delete-and-recreate in `didMigrate` | Breaks external references (other models hold the old ID), insertion-order-dependent, corrupts relationships |

**Predicate safety with `UUID?` comparison**: The §14a anti-pattern
(`reviewing-code-changes` skill) forbids **optional chains** in
`#Predicate` (`$0.relation?.id == foo`), not the direct comparison
of two optionals. `$0.workoutId == workoutId` with
`workoutId: UUID?` vs the function parameter `UUID` compiles into a
flat SQL comparison (`WHERE workoutId = ?`), not a join.
That is **not** an anti-pattern and is fully indexable.

**Consequence for production code**: Production save paths
(`ExerciseModel.from(_:sortOrder:workout:)`, all direct creators)
must continue to set the real `workoutId`. The `nil` state exists
only transiently during `didMigrate` and for orphans (rows without a
`@Relationship` partner). Reviewers check: every new creator calls
the helper or sets `workoutId` explicitly.

### Test obligation (binding)

Per custom stage a test **must** exist in `Packages/FitnessStorage/Tests/.../`:

- Setup: in-memory container with `SchemaVN.self` (old version)
- Create data that represents the old schema
- Close the container, open a new container with `AppMigrationPlan` and the target schema
- Assert: the data is correctly present in the new schema, backfill values are right,
  no data loss

Lightweight stages do not need a test (Apple's mechanics are tested), only
custom stages.

### StorageContainer integration

`StorageContainer.swift` is switched from:

```swift
let schema = Schema([WorkoutModel.self, ExerciseModel.self, ...])
return try ModelContainer(for: schema)
```

to:

```swift
return try ModelContainer(
    for: SchemaVN.self,
    migrationPlan: AppMigrationPlan.self
)
```

`Schema(...)` from `[Model.Type]` is an implicit schema V1; once switched to
`VersionedSchema` all future versions stay mechanical.

## Consequences

### Positive

- Every schema change follows a mechanical path. Code review checks:
  "new file `SchemaVN+1.swift`? `MigrationPlan.swift` updated?
  Does the custom stage have a test?"
- Migrations are **tested**. A crash-after-app-update is caught in CI,
  not by the first user.
- App code (`Models/`) stays at the current state. Only schema files grow.
- Rollback / forensics possible: each schema version is self-contained and
  can be loaded in isolation.

### Negative

- On every schema change the engineer must write a snapshot of the current
  form **before** the code change (hybrid rule step 2).
  If they forget, the migration test is not writable and the
  pre-commit hook (adr-required) blocks the commit. That is discipline
  effort; the hybrid keeps it as small as possible (only the
  actually changed class).
- The initial switch in T3 takes more effort than "quickly add `workoutId: UUID`
  to `ExerciseModel`". That is the price of making T4, T5, … all cheap.

### Neutral

- App code keeps referencing `ExerciseModel`, `WorkoutModel`, etc. without a
  schema prefix — the `Models/` files are the live definitions
  (= latest version). Snapshot classes under `SchemaVN.<Name>` are
  only referenced internally in schema/migration/test code.
- CloudKit migration (future ADR-0004) benefits from a versioned schema
  because CloudKit schemas are also versioned and allow a 1:1 mapping to our
  `SchemaVN`.

## When this decision must be re-evaluated

- Apple ships a fundamentally new migration API (e.g. a declarative
  migration DSL). Currently unlikely; SwiftData is a young
  framework and Apple keeps investing in `SchemaMigrationPlan`.
- The team migrates away from SwiftData. A complete-rewrite scenario, its own ADR.

## References

- ADR-0001 (Model as UI SoT — defines why `@Model` is used in production at all)
- ADR-0002 (FitnessPersistenceUI — who interacts with the schema)
- T3 (schema migration `workoutId: UUID` — the first real application of this ADR)
- Apple `SchemaMigrationPlan`: <https://developer.apple.com/documentation/swiftdata/schemamigrationplan>
- Apple `VersionedSchema`: <https://developer.apple.com/documentation/swiftdata/versionedschema>
- Apple `MigrationStage`: <https://developer.apple.com/documentation/swiftdata/migrationstage>
- WWDC23 "Model your schema with SwiftData": <https://developer.apple.com/videos/play/wwdc2023/10195/>

Co-authored-by: Cursor <cursor@cursor.com>
