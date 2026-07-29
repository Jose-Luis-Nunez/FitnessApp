# 0010 — Workout-scoped exercise-order learning

* Status: accepted
* Date: 2026-07-29
* Deciders: jose.nunez

## Context

The flattened List View should adapt to the order in which a user actually
starts exercises during a workout. The existing `ExerciseModel.sortOrder`
cannot represent this behavior: it is category-local, manually maintained, and
is also consumed by category screens whose ordering must remain unchanged.

Learning the order crosses four package boundaries:

- `FitnessTraining` knows when a genuinely new exercise session starts.
- `FitnessExercise` owns the global Reset All use case that ends an observed
  workout cycle and the List View that consumes a confirmed order.
- `FitnessStorage` persists workout-local pending, candidate, and learned state.
- `FitnessCore` provides the storage protocol shared across those packages.

The learned order is usage-derived state, not part of the workout definition.
It must therefore remain local to one workout, survive app restarts, be deleted
with that workout, and stay out of workout exports and duplicates. A single
accidental deviation must not immediately reorder the List View.

## Options

- **A — Reuse `ExerciseModel.sortOrder`:** Rewrite every exercise's existing
  sort order after each workout. This conflates category-local manual order with
  learned cross-category usage and would change category and overview behavior.
- **B — Keep learning state in a ViewModel or coordinator cache:** Record starts
  in memory and sort the List View from that snapshot. This loses observations
  on app restart, gives UI lifetime authority over domain data, and duplicates
  state across category coordinators.
- **C — Persist a workout-scoped order model and record explicit coordinator
  events:** Add a separate SwiftData model, expose it through a Core protocol,
  record only genuine new sessions in `TrainingCoordinator`, finalize only from
  global Reset All, and let the List View query the confirmed result.
- **D — Persist an append-only workout-event history:** Store every start/reset
  event and derive the order by replaying the log. This preserves more history
  than the product needs and adds retention, compaction, and replay complexity.

## Decision

Choose **Option C**.

Schema V6 adds one `WorkoutExerciseOrderModel` per workout with:

- `pendingExerciseIds` for the first start of each exercise in the current cycle
- `candidateExerciseIds` and `candidateRepeatCount` for consecutive observations
- `learnedExerciseIds` for the confirmed List View order

`WorkoutExerciseOrderStoring` is the cross-package boundary. Its
`recordStart(workoutId:exerciseId:)` operation is invoked by
`TrainingCoordinatorCache` through the coordinator's private
`onNewSessionStarted` callback. The callback fires only after a successful new
session start; resuming or focusing an existing session records nothing.

`ResetAllExercisesUseCase` calls `finalizeCycle(workoutId:)` before cancelling
coordinator sessions and resetting exercises. A candidate is promoted only
after the same complete order is observed twice consecutively. Partial cycles
append unstarted exercises using the prior stable relative order. Deleted or
deactivated identifiers are pruned or ignored.

The List View reads exercises and the learned order through one
workout-scoped SwiftData query host whose identity is rebound with
`.id(workoutId)`. It sorts confirmed identifiers first and appends unknown,
new, or reactivated exercises using the existing `(category, sortOrder)`
fallback. Overview and category screens continue to use their existing order.

This decision does not make the learned state exportable or duplicable. Deleting
a workout deletes its order model; duplicating or exporting a workout copies
only its definition.

## Consequences

- **Positive:** Learned and manual ordering have separate meanings and storage.
- **Positive:** Training remains the sole authority for distinguishing new
  sessions from resumes, so every entry point records consistently.
- **Positive:** Two consecutive confirmations prevent one-off deviations from
  causing UI churn.
- **Positive:** The order is workout-local, durable, migration-tested, and
  reactively consumed by SwiftUI.
- **Positive:** Category and Overview behavior remains unchanged.
- **Negative:** Schema V6 and an additional persisted model increase migration
  and deletion-cleanup responsibility.
- **Negative:** Reset All now has an ordering contract:
  finalize learning, cancel sessions, then reset exercises.
- **Neutral:** Usage-derived learning data is intentionally excluded from
  workout import/export and duplication.
- **Neutral:** A reactivated exercise returns through fallback ordering until a
  later sequence confirms a position again.

## References

- ADR-0001 — `@Model` as UI Single Source of Truth
- ADR-0003 — Coordinator session-state contract
- ADR-0005 — SwiftData Schema Migration Strategy
- `Packages/FitnessCore/Sources/FitnessCore/WorkoutExerciseOrderStoring.swift`
- `Packages/FitnessStorage/Sources/FitnessStorage/WorkoutExerciseOrderStorageService.swift`
- `Packages/FitnessStorage/Sources/FitnessStorage/Schema/SchemaV6.swift`
- `Packages/FitnessTraining/Sources/FitnessTraining/TrainingCoordinator.swift`
- `Packages/FitnessExercise/Sources/FitnessExercise/UseCases/ResetAllExercisesUseCase.swift`
