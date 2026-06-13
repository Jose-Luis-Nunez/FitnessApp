# 0003 — Training Coordinator session state is non-persistent and blocking

* Status: accepted
* Date: 2026-04-19
* Deciders: jose.nunez

## Context

`TrainingCoordinator.activeSessions[id].currentExercise` is today an
`Exercise` struct copy, held during an active training session.

With ADR-0001 (`@Model` as UI SoT) a potential conflict arises with
parallel mutations:

- The user starts training for exercise X. The coordinator holds a snapshot with,
  e.g., `sets = 3` at session start.
- The user edits exercise X in parallel in the edit sheet. Mutation on the
  `@Model` instance: `model.sets = 5`. SwiftData saves → `@Query` and
  `@Bindable` views immediately see `5`. But:
- What applies to the running session? The coordinator snapshot with `sets = 3`
  (the user started before the edit) or the new `@Model` truth with `sets = 5`?

Both naive solutions lead to bugs:

- **Ignore the snapshot / read the live `@Model`** → sets the user has already
  completed can suddenly fall out of the planned set or appear twice.
- **Overwrite the snapshot** → user edits during a session are discarded for the
  session without the UI communicating it.

## Options

- **A**: The coordinator observes `@Model` mutations and merges them into the
  running session (complex, race-prone, hard to test)
- **B**: The UI **blocks** edit operations on exercise X during an active
  session (edit button disabled, sheet refused with a hint)
- **C**: The coordinator holds a `PersistentIdentifier` instead of a struct copy,
  reading live from the `@Model` every frame — mutations propagate transparently
  (SwiftData observation handles updates)
- **D**: Status quo — no guarantee, a documented "don't do that"

## Decision

**Option B as the main rule + convention C-Light for the coordinator internals**:

### 1. UI edit block during an active session

As long as `coordinator.activeSessions[exerciseId]` exists:

- The edit button on exercise X is **disabled** in all consumer views
  (list, detail, card)
- The edit sheet does not open (a tap shows a brief banner "Exercise in progress —
  editing possible after training ends")
- Reset / delete of exercise X is likewise blocked during a session

### 2. Coordinator state is non-persistent

`activeSessions`, `ActiveSetViewModel.completedSetCount`, and timer state are
**explicitly ephemeral**:

- On an app kill mid-training **session progress is lost** (as is already the
  case today — no regression).
- No SwiftData persistence of these fields. They are pure live session state.
- On app foreground after backgrounding the session is resumed after a short
  pause (existing behaviour); after a long pause a future mechanism could
  trigger a foreground sync (out of scope here).

### 3. The coordinator holds domain-relevant fields as a struct copy

- The coordinator keeps `currentExercise: Exercise` as a struct at
  session start (which it does today). The set plan is frozen at session time.
- Persisted set results are written directly to `ExerciseModel`
  (via `FinishExerciseUseCase`: `model.isCompleted = true; context.save()`).
- The coordinator references the `@Model` identity via `id: UUID` (the DTO and
  the model share the same `id`), but does not read the plan live from the
  model — that is exactly the snapshot guarantee of the edit block.

## Consequences

### Positive

- The edit-while-training race is **excluded by construction**.
- The coordinator stays lean, clearly separated from persistence in terms of domain.
- The persistence path is unambiguous: all persisted set mutations go through
  `@Model` + `context.save()`. A single write direction.
- Tests can still set up the coordinator with a `struct Exercise`, without
  needing a `ModelContainer` (coordinator tests stay lean).

### Negative

- The UI must provide edit-block state — a new computed state in the
  consumer views (edit-button `isEnabled` logic).
  This extra work is concentrated in T7 (`TrainingModelView` pilot).
- App kill mid-training loses session progress. **Accepted** and
  documented in onboarding/UX (a future ticket card for a persistent
  session if user feedback demands it).

### Neutral

- `struct Exercise` in `FitnessCore` stays — it is the coordinator's plan DTO.
- `ExerciseModel` becomes the UI source (ADR-0001), but the coordinator does not
  hold it directly. A clear layer separation: coordinator → struct,
  UI → @Model.

## References

- ADR-0001 (`@Model` as UI SoT — explains why the coordinator snapshot
  carried a potential conflict risk)
- ADR-0002 (`FitnessPersistenceUI` — where the edit-block views would live)
- T7 (TrainingModelView implements the edit block in the pilot view)
- T8 (legacy cleanup accounts for the coordinator contract)
