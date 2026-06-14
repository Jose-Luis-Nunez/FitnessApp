# 0009 — Targeted, non-destructive single-exercise update (no delete+reinsert)

* Status: accepted
* Date: 2026-06-14
* Deciders: jose.nunez, Claude

## Context

`ExerciseStorageService` persists exercises with a single primitive: `saveForWorkout(_:workoutId:category:)`, which **deletes every `ExerciseModel` for the (workout, category) and reinserts the supplied array**. Every edit — rename, weight, seat, complete, reset — went through `ExerciseManagementService.updateExercise` → load-all → replace-one → `saveForWorkout`, i.e. a full destructive replace for a one-field change.

The service runs on its **own** `ModelContext` (`ModelContext(resolved)`), separate from the SwiftUI main context that the views' `@Query<ExerciseModel>` observe (ADR-0001 / ADR-0002).

This combination is fragile. A bug surfaced when the seat-edit feature wrote `model.seatSetting` **directly** on a main-context `@Query` model and a subsequent edit ran `saveForWorkout` on the storage context: the deleted row lingered as a stale object in the main-context `@Query`, rendering as a **phantom empty card** — a gap between exercises that grew with each repeat. Reproduced reliably: training seat-save → cancel → idle seat-save → gap.

The proximate fix (route the seat write through the service instead of mutating the `@Model`) removed the *trigger* but left the *hazard*: a destructive delete+reinsert for every single-exercise update, which also churns the `@Query` and can flicker an in-progress training card.

## Options

- **A**: Keep `saveForWorkout` for all edits; only forbid direct main-context writes. (Conform to the flawed pattern — leaves the destructive replace + churn in place.)
- **B**: Unify the storage service onto the SwiftUI main context so direct `@Model` mutation is safe. (Broadest blast radius; touches container/context wiring every feature depends on.)
- **C**: Add a **targeted, non-destructive** `updateExercise(_:)` that mutates a single existing row in place (fetch by `id` → `ExerciseModel.update(from:)` → save) and route single-exercise edits through it. Keep `saveForWorkout` for add/delete/reorder/bulk.

## Decision

Option C. `ExerciseStoring` gains `func updateExercise(_ exercise: Exercise)`; `ExerciseStorageService` implements it as an in-place update that preserves row identity, `sortOrder`, and the `workout` relationship. `ExerciseManagementService.updateExercise` (and therefore `completeExercise`/`resetExercise`) delegate to it. `addExercise`/`resetAllExercises` continue to use the bulk `saveForWorkout`.

The view layer still does not mutate `@Model` directly; the training seat edit persists via `TrainingCoordinator.updateActiveSeat` → `onExerciseUpdate` → `ExerciseManagementService.updateExercise` → the targeted path.

## Consequences

- **Positive**: eliminates the phantom-card hazard class at the source — an in-place property change keeps the SwiftData row identity stable, so the main-context `@Query` updates smoothly instead of stranding a deleted object.
- **Positive**: no full delete+reinsert for single edits → no churn, no flicker of an in-progress training card on a mid-session seat edit.
- **Positive**: cheaper writes (one fetch + one mutation vs. delete-N + insert-N).
- **Neutral**: still two `ModelContext`s. This is not Option B; full single-context unification (the ADR-0001 end state) remains future work (T8). Option C is the smallest change that removes the destructive replace for the common case.
- **Negative / watch**: `saveForWorkout` remains the path for add/delete/reorder, so two write shapes coexist. Documented here and in the service so the split is intentional, not accidental.

## References

- ADR-0001 (Model as UI source of truth), ADR-0002 (PersistenceUI package).
- `Packages/FitnessStorage/Sources/FitnessStorage/ExerciseStorageService.swift` (`updateExercise`)
- `Packages/FitnessStorage/Sources/FitnessStorage/ExerciseManagementService.swift` (`updateExercise`)
- `Packages/FitnessCore/Sources/FitnessCore/ExerciseStoring.swift`
- `Packages/FitnessTraining/Sources/FitnessTraining/TrainingCoordinator.swift` (`updateActiveSeat`)
