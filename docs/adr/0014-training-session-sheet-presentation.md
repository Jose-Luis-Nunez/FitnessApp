# 0014 — Training session sheet presentation

* Status: accepted
* Date: 2026-08-02
* Deciders: jose.nunez

## Context

Active training was previously a `NavigationDestination.training` push. That
made the Category/List origin disappear even though the coordinator already
kept active sessions independently and returning from training did not cancel
them. The new product layout must keep that origin visible behind a partial
bottom sheet, retain the app bottom bar, and allow backdrop, grabber, or Back
to hide the workspace without ending the exercise.

The live exercise row must remain SwiftData-backed. `FitnessTraining` must stay
free of `ExerciseModel`, and presentation state must not become session state.

## Options

- **A — Keep navigation and imitate the parent behind it:** Reconstruct a
  Category/List snapshot inside the training destination.
- **B — Use a native `.sheet`:** Present from each start surface with a system
  detent.
- **C — Add independent router presentation state:** Keep the real parent
  mounted and render one app-level custom sheet below the global bottom bar.

## Decision

Choose **Option C**.

`AppRouter` owns an optional `TrainingPresentation` containing only the
exercise id and category. `presentTraining` and `dismissTraining` never mutate
`NavigationPath`. The app root mounts a single `TrainingSheetView` above the
current Category/List view. A custom overlay is used because the global bottom
bar must remain in the app-level composition; a native sheet would cover it
and would duplicate presentation ownership across both start surfaces.

`TrainingSheetView` resolves `ExerciseModel` through an id-filtered `@Query`
and bridges to `TrainingCoordinator` with `model.toDomain()`. The coordinator
continues to own session lifetime, progress, focus, and timer state. Backdrop,
grabber, Back, and tab navigation dismiss presentation only. Cancel and Finish
remain the only coordinator paths that remove the active session.

The sheet does not render the active exercise metric card. It composes the
existing set rows and controls with a shared `ExerciseMuscleIconView`. Only the
bounded set column scrolls; the title, muscle icon, timer, and action bar stay
fixed. Standard and bilateral sessions share this structure and keep one
`ActiveSetViewModel`. The left column groups the fixed title with a viewport of
exactly three logical sets; additional standard rows or bilateral L/R pairs
scroll inside that viewport. The right column top-aligns the muscle icon above
the compact timer, and the unchanged action component follows directly below
the two columns. The session/action group is bottom-aligned with an explicit
clearance for the persistent app Bottom-Bar, so any remaining detent space is
distributed above the group rather than below the action buttons.

## Consequences

- **Positive:** Category/List state and SwiftData identity remain mounted while
  training is visible and update immediately after Finish.
- **Positive:** Hide/resume behavior matches coordinator session ownership and
  requires no copied model or polling synchronization.
- **Positive:** Both start surfaces use one presentation host and keep package
  dependency direction unchanged.
- **Negative:** The app root owns custom sheet geometry and dismissal gestures
  rather than receiving native detent behavior.
- **Negative:** Training UI tests must start from Category/List; direct training
  navigation launch is no longer valid.
- **Neutral:** Existing exercise-card active-variant APIs remain available, but
  the training sheet no longer mounts that card.

## References

- ADR-0001 — @Model as UI Single Source of Truth
- ADR-0003 — Coordinator session-state contract
- ADR-0009 — Targeted, non-destructive single-exercise update
- ADR-0011 — Logical sets and bilateral execution steps
- `Packages/FitnessExercise/Sources/FitnessExercise/AppRouter.swift`
- `FitnessApp/Features/Training/TrainingView.swift`
- `Packages/FitnessTraining/Sources/FitnessTraining/TrainingSessionComponent.swift`
