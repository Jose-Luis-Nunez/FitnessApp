# 0015 — Batched analytics snapshots and targeted UI invalidation

* Status: accepted
* Date: 2026-08-03
* Deciders: jose.nunez

## Context

Analytics screens and exercise cards derived several values from the same
exercise histories. The previous implementation repeatedly crossed the
storage boundary while SwiftUI evaluated cards, Total Analytics, and Schedule.
On workout-sized data sets this produced per-exercise reads, repeated grouping
and sorting, and broad card refreshes through a global change counter.

The optimization must preserve the existing SwiftData schema, domain values,
navigation, and visible calculations. `FitnessCore` remains the protocol and
domain boundary, `FitnessStorage` remains the SwiftData owner, and SwiftUI
views must not gain persistence responsibility.

## Options

- **A — Keep individual reads and optimize calculations only:** Memoize chart
  and summary calculations while retaining one storage call per exercise. This
  is local and simple, but does not remove the dominant N+1 read pattern.
- **B — Expose SwiftData queries directly to analytics views:** Let each view
  fetch the models it needs and rely on `@Query` observation. This provides
  automatic updates, but reverses package ownership and couples analytics
  presentation to persistence models.
- **C — Add workout-scoped batch reads and materialize immutable snapshots:**
  Fetch exercises once, fetch analytics entries in bounded ID chunks, group
  them by exercise identifier, and derive each screen's visible state from the
  resulting domain snapshot. Cache card histories and publish observable
  per-exercise cache revisions.

## Decision

Choose **Option C**.

`FitnessCore` defines failure-aware workout-wide and multi-exercise read APIs and
the Sendable `WorkoutAnalyticsSnapshot`, containing workout exercises, flat
analytics entries, and `entriesByExerciseId`. `TotalAnalyticsStoring` requires
an explicit workout ID and propagates snapshot read failures instead of
representing them as an empty or missing snapshot. Default protocol
implementations remain only where the legacy contract is semantically complete.
`FitnessStorage` supplies optimized production implementations. Duplicate IDs
are normalized only at the public analytics-storage boundary and queried in
fixed chunks of 200; workout-internal Exercise IDs remain an asserted invariant.

`TotalAnalyticsViewModel` and `ScheduleViewModel` load one workout snapshot and
materialize the state consumed by their views. Failed refreshes never cache a
successful-looking empty history or combine values from different read
attempts. SwiftUI `body` evaluation must not perform storage reads.
`AnalyticsViewModel` caches histories per exercise,
prefetches missing card histories in workout/category-wide batches, and updates
only the affected exercise revisions after a batch or write. A Factory-scoped
singleton is shared by Home, category, training, and
workout-log surfaces, so successful writes replace the same cached histories
that cards read. The cache is bounded to 128 histories. Cards consume cached
summaries only; a cache miss renders the empty summary until the parent batch
loads it, avoiding any dependency on SwiftUI `.task`/`.onAppear` ordering.
Each card observes only its exercise-specific revision. Failed reads publish no
revision and do not populate the cache, so a later lifecycle pass can retry.
There is no global counter, single event slot, or polling compatibility path.

Cached values are performance state, not a second persistence owner. Storage
and SwiftData models remain authoritative; successful analytics mutations
reload the affected exercise history, and screen lifecycle refreshes rebuild
workout-wide materialized state. No schema, migration, export, or navigation
change is part of this decision.

## Consequences

- **Positive:** Workout analytics reads scale by bounded batches instead of by
  every calculation and card.
- **Positive:** Total Analytics and Schedule perform deterministic in-memory
  derivation after one snapshot load.
- **Positive:** An analytics write invalidates only the affected exercise card.
- **Positive:** Persistence ownership and package dependency direction remain
  unchanged.
- **Negative:** ViewModels now own explicit cache invalidation and lifecycle
  materialization responsibilities.
- **Negative:** Protocols and test doubles must implement or inherit the new
  batch-read behavior.
- **Neutral:** Default protocol implementations may still use individual reads;
  optimized batching is guaranteed by production storage services, not every
  conformer.
- **Neutral:** Moving SwiftData reads to a `ModelActor` remains a future option
  if measured main-actor work exceeds the product threshold.

## References

- ADR-0001 — @Model as UI Single Source of Truth
- ADR-0002 — FitnessPersistenceUI Package
- ADR-0013 — Workout analytics batch append
- `Packages/FitnessCore/Sources/FitnessCore/WorkoutAnalyticsSnapshot.swift`
- `Packages/FitnessCore/Sources/FitnessCore/AnalyticsStoring.swift`
- `Packages/FitnessStorage/Sources/FitnessStorage/AnalyticsStorageService.swift`
- `Packages/FitnessStorage/Sources/FitnessStorage/TotalAnalyticsStorageService.swift`
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/AnalyticsViewModel.swift`
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/TotalAnalyticsViewModel.swift`
- `Packages/FitnessSchedule/Sources/FitnessSchedule/ScheduleViewModel.swift`
