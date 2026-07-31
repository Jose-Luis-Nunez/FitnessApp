# 0013 — Workout analytics batch append

* Status: accepted
* Date: 2026-08-01
* Deciders: jose.nunez

## Context

Users need to record a complete missed workout without repeating the existing
calendar flow for every exercise. The new flow starts from a workout tile,
loads that workout's active exercises, creates editable analytics drafts from
their current training configuration, and saves the selected exercises for one
date.

This behavior crosses package boundaries:

- `FitnessWorkouts` owns the workout list and the presentation entry point.
- `FitnessAnalytics` owns analytics draft editing and save orchestration.
- `FitnessStorage` owns the SwiftData transaction.
- `FitnessCore` provides the storage boundary shared by those packages.

Existing analytics entries for the same exercise and day must remain intact.
One confirmation must append exactly one entry per selected exercise, and a
partial storage failure must not leave half of the workout recorded. The
feature does not require querying or replacing same-day history, changing the
exercise configuration, or introducing a historical workout-session model.

## Options

- **A — Reuse the single-exercise calendar flow repeatedly:** Present the
  existing entry screen once per exercise and save each result independently.
  This avoids a new orchestration layer, but keeps the slow interaction and can
  persist only part of a workout when a later save fails.
- **B — Implement the batch in `FitnessWorkouts`:** Let the workout screen
  construct analytics entries and call storage directly. This keeps the entry
  point local but gives the workouts package responsibility for analytics
  rules and draft validation.
- **C — Add a workout-entry feature to `FitnessAnalytics` with an atomic append
  storage boundary:** Present a public analytics view from `FitnessWorkouts`,
  keep draft creation and terminal save state in an observable analytics
  ViewModel, and append the resulting entries through a Core protocol
  implemented by `FitnessStorage`.
- **D — Add a persisted historical workout-session model:** Store a session
  entity and relate every new analytics entry to it. This would make the batch
  relationship explicit, but requires a schema migration and new session
  lifecycle semantics that the current product does not consume.

## Decision

Choose **Option C**.

`FitnessAnalytics` exposes `WorkoutAnalyticsEntryView` and owns
`WorkoutAnalyticsEntryViewModel`. The ViewModel loads active workout exercises,
creates one selected draft per exercise from `Exercise.trainingSteps`, and
allows the existing analytics editor to update those drafts without saving or
mutating the source `Exercise` values.

`SaveWorkoutAnalyticsUseCase` filters invalid empty entries and submits the
complete batch through `WorkoutAnalyticsBatchStoring`. The protocol lives in
`FitnessCore`; `AnalyticsStorageService` implements it by inserting all entries
into one SwiftData context and saving once. A failed save rolls the context
back. The operation is append-only: it does not load, replace, or collapse
entries already stored for the same date.

The ViewModel's save lifecycle is terminal for a successful presentation:
`editing → saving → saved`. Only `editing` may begin a save. The view disables
its controls during saving and dismisses after success, preventing the same
batch from being submitted repeatedly from one presentation. A failed atomic
save returns to `editing` and exposes an error for retry.

`FitnessWorkouts` adds an explicit dependency on `FitnessAnalytics` solely to
present this feature from a workout tile. No SwiftData schema, `Workout`,
`Exercise`, or `AnalyticsEntry` shape changes. Entries remain associated with
the workout indirectly through their exercise identifiers and shared date;
seat settings and a historical workout session are intentionally not stored.

## Consequences

- **Positive:** A complete missed workout can be entered and confirmed in one
  compact flow.
- **Positive:** Existing same-day analytics history is preserved; each selected
  exercise receives exactly one additional entry.
- **Positive:** One context save makes the workout batch atomic and prevents a
  partially persisted workout.
- **Positive:** Analytics validation and draft behavior remain owned by
  `FitnessAnalytics`, while persistence remains owned by `FitnessStorage`.
- **Positive:** The terminal save state protects one presentation from duplicate
  submissions.
- **Negative:** `FitnessWorkouts` now depends on `FitnessAnalytics`, increasing
  the package graph for the presentation entry point.
- **Negative:** The Core protocol is a specialized append capability in
  addition to the existing `AnalyticsStoring` API.
- **Neutral:** Multiple entries for the same exercise and date remain separate
  analytics records by design.
- **Neutral:** There is no durable batch or workout-session identifier, so the
  saved entries cannot later be managed as one historical session without a
  new architectural decision and schema migration.

## References

- `Packages/FitnessCore/Sources/FitnessCore/WorkoutAnalyticsBatchStoring.swift`
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/WorkoutAnalyticsEntryView.swift`
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/WorkoutAnalyticsEntryViewModel.swift`
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/UseCases/SaveWorkoutAnalyticsUseCase.swift`
- `Packages/FitnessStorage/Sources/FitnessStorage/AnalyticsStorageService.swift`
- `Packages/FitnessWorkouts/Sources/FitnessWorkouts/WorkoutsScreen.swift`
- `.claude/references/user-flows.md`
