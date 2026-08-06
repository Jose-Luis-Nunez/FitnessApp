# 0016 — Demand-loaded exercise-card analytics

* Status: accepted
* Date: 2026-08-06
* Deciders: jose.nunez

## Context

ADR-0015 removed repeated card reads by batch-prefetching complete exercise
histories from parent lists. That removed the original N+1 history pattern, but
it also loaded every historical entry merely because a category or workout list
became visible. Exercise cards need three different data depths: whether a Last
run action exists, the latest run's sets, and the complete history used for
coaching phases.

The solution must preserve the SwiftData schema and package ownership. Views
must not query persistence directly, and workout-wide Total Analytics and
Schedule snapshots remain unchanged.

## Options

- **A — Keep parent history prefetch:** minimizes query count but loads unused
  histories and set payloads.
- **B — Persist a card-summary field on Exercise:** makes rendering cheap but
  duplicates analytics truth and requires migration and write synchronization.
- **C — Expose intent-specific reads and load progressively:** query only
  existence for the affordance, the latest entry after Last run is tapped, and
  full history after the coaching-tip drill-down.

## Decision

Choose **Option C**, partially superseding only the exercise-card prefetch
portion of ADR-0015.

`AnalyticsStoring` exposes failure-aware existence and latest-entry reads.
Production existence checks fetch at most one SwiftData identifier without
materializing an analytics entry; latest reads fetch at most one complete entry.
`AnalyticsViewModel` remains the Factory-scoped, MainActor-isolated cache owner
and keeps availability, latest entry, and history as separate per-exercise cache
stages under one 128-exercise bound. Exercise-specific revisions remain the only
card invalidation signal.

Parent exercise lists perform no analytics prefetch. `IdleActiveCardModelView`
checks only existence on appearance, loads the latest entry after Last run is
tapped, and loads full history after the coaching-tip button is tapped.
`InactiveCardModelView` loads the latest entry only when expanded. Successful
workout-log writes publish availability and invalidate affected detail stages
without re-reading histories.

## Consequences

- **Positive:** Scrolling materializes no analytics entries or set payloads.
- **Positive:** Card reads follow explicit UI intent and remain exercise-scoped.
- **Positive:** No schema, migration, or parallel persistence owner is added.
- **Negative:** A first appearance may execute one identifier-only existence
  query per uncached idle exercise card.
- **Negative:** Cache invalidation must distinguish availability, latest entry,
  and complete history.
- **Neutral:** Workout snapshots and batch storage remain authoritative for
  Total Analytics and Schedule.

## References

- ADR-0001 — @Model as UI Single Source of Truth
- ADR-0002 — FitnessPersistenceUI Package
- ADR-0015 — Batched analytics snapshots and targeted UI invalidation
- `Packages/FitnessCore/Sources/FitnessCore/AnalyticsStoring.swift`
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/AnalyticsViewModel.swift`
- `Packages/FitnessStorage/Sources/FitnessStorage/AnalyticsStorageService.swift`
