# 0007 — SessionTrainingCache entfernen, ResetAllExercisesUseCase auf TrainingCoordinatorCache umstellen

* Status: accepted
* Date: 2026-05-02
* Deciders: jose.nunez, Cursor

## Context

The codebase maintained two parallel caches for active training sessions:

1. **`TrainingCoordinatorCache`** — per-category `TrainingCoordinator`, each owning a `[Exercise.ID: ActiveSetViewModel]` map (`activeSessions`). This is the authoritative source of truth for training state.
2. **`SessionTrainingCache`** — a flat `[MuscleCategoryGroup: ActiveSetViewModel]` dictionary, registered as a DI singleton.

`SessionTrainingCache` was only consumed by `ResetAllExercisesUseCase`, which iterated its `activeSetVMs` to call `cancelActiveSet()` on each VM. This created two problems:

- **Stale coordinator state**: calling `cancelActiveSet()` on the VM reset the VM's internal tracking, but the coordinator's `activeSessions`, `activeExercises`, and `focusedExerciseId` were left pointing at the now-cancelled VM — a consistency bug.
- **Redundant cache**: the same VM instances were already reachable through `TrainingCoordinatorCache` → `TrainingCoordinator.activeSessions`. Maintaining a second cache added indirection without value.

## Options

- **A**: Keep both caches, add sync logic to keep them consistent.
- **B**: Remove `SessionTrainingCache`, rewire `ResetAllExercisesUseCase` to use `TrainingCoordinatorCache` and call `coordinator.cancelTraining(for:)` which cleans up both VM and coordinator state.

## Decision

Option B. `ResetAllExercisesUseCase` now injects `\.trainingCoordinatorCache`, iterates all categories, and calls `coordinator.cancelTraining(for:)` for each active session. The `SessionTrainingCache` class, protocol, DI registration, and dedicated tests are deleted.

## Consequences

- **Positive**: single source of truth for active sessions; the stale-coordinator-state bug is eliminated; fewer types to maintain.
- **Positive**: `ResetAllExercisesUseCase` tests now exercise the full coordinator cancel path, catching regressions earlier.
- **Neutral**: no API change for any view or other consumer — `TrainingCoordinatorCache` was already the primary access point everywhere else.
- **Negative**: none identified. No external consumer depended on `SessionTrainingCaching`.

## References

- ADR-0003 (Coordinator Session-State Vertrag) — defines the coordinator as the authoritative session owner.
- `Packages/FitnessTraining/Sources/FitnessTraining/TrainingCoordinatorCache.swift`
- `Packages/FitnessExercise/Sources/FitnessExercise/UseCases/ResetAllExercisesUseCase.swift`
