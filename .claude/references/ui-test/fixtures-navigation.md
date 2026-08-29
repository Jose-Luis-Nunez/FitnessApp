# Fixtures and Direct Navigation

Seeding state and jumping straight to a screen.

## Test Fixtures

Mock data is defined in `Fixtures/ExerciseFixtures.swift` as `TestExerciseFixture` structs. Training tests launch an explicit Category or List fixture and then tap its Start control; the app requires all exercise fields (no defaults).

```swift
try launch(exerciseList: .defaultArmsExercise)
try launch(exerciseCategory: .defaultArmsExercise)
try launch(
    exerciseCategory: .bilateralTorsoExercise,
    additional: [.defaultArmsExercise]
)
```

Named presets (e.g. `.defaultArmsExercise`) keep tests readable. For custom scenarios, create a fixture inline:

`launch(exerciseCategory:additional:seedAnalyticsHistory:)` can opt into one
complete analytics session dated yesterday. This keeps the completed card's
set row genuinely tappable while leaving today's Analytics screen empty for a
real Add-then-Edit flow. Dynamic prefix taps choose the largest visible,
hittable match because SwiftUI may propagate one container identifier to
multiple descendants; never rely on `firstMatch` for these card prefixes.

```swift
let heavy = TestExerciseFixture(name: "Deadlift", weight: 120.0, reps: 5, sets: 5, noSeats: true, icon: "dumbbell", category: "back")
try launch(exerciseCategory: heavy)
```

## Direct Navigation

For tests that focus on a specific screen, use `BaseTest` launch helpers to skip intermediate screens:

```swift
// Category with an explicit fixture; tap Start to present training
try launch(exerciseCategory: .defaultArmsExercise)
tapOn(MuscleCategoryIDs.startExercise)

// Category screen
try launch(category: "arms")

// Category-selection overview (deterministic UI-test launch)
try launchCategorySelection()

// Schedule screen
try launchSchedule()

// Profile screen with deterministic body data and accent preference
try launchProfile()

// Home / Workouts screen (default)
launchHome()
```

The app reads the `UITEST_CONFIG` environment variable and uses `AppRouter.replaceAll(with:)` to build the navigation stack programmatically so back-navigation still works. For training, **all exercise fields are required** -- the app will not navigate if any are missing.

**When to use which:**

| Scenario | Launch method |
|----------|--------------|
| Testing the full user journey (home to finish) | `launchHome()` + navigate via DSL |
| Testing training behavior | `launch(exerciseCategory:)` or `launch(exerciseList:)`, then tap Start |
| Testing another specific screen | `launch(category:)`, `launchSchedule()`, or `launchProfile()` |
| Comparing Category/Workout overview geometry | `launchCategorySelection()` then tap the Workouts tab |

Supported screens: `.home` (category-selection overview), `.category`, `.schedule`, `.profile`. Training is a presentation over `.home` list mode or `.category`, not a direct launch screen.
