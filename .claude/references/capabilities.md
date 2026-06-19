# Capabilities — what the user can already do today

> Pure bullet list. If an idea already attaches to one of these points: extend rather than build anew.

## Managing workouts

- Create multiple workouts (no limit)
- Rename workouts (free text)
- Duplicate workouts (including all contained Exercises with their own UUIDs)
- Delete workouts (confirmation step, **invariant: ≥1 workout must remain**)
- Flag one workout as "Default" — on app launch you navigate directly there
- Visible per workout tile: number of Exercises (in the colored ring at the top left)

## Managing Exercises per workout & muscle group

- Create Exercises with the following properties:
  - **Name** (free text)
  - **Weight** (picker, predefined options via `WeightOptionsGenerator`)
  - **Reps** (1...50)
  - **Sets** (1...10)
  - **Seat setting** (free text, optional, with a `noSeats` flag when not relevant)
  - **Icon** (chosen by swiping the body-image gallery in `ExerciseIconHeader`)
  - **Category** (`MuscleCategoryGroup`: arms / chest / back / legs / abs)
  - **Goal** (target Reps or Weight — read by `AnalyticsView`)
- Edit Exercises individually (Name / Weight / Seat / full — four `ExerciseEditMode`s)
- Delete Exercises
- "Reset" Exercises individually (Sets back to "not yet done", keeps the Exercise)
- **Reset all** for a whole category via the mini menu on Home

## Training (live session)

- Start a training session per Exercise — the Coordinator is cached per category
- Three actions per Set:
  - **Done** (Reps achieved as planned → `completedDone`)
  - **More** (more Reps achieved → `completedMore`, prompt for the actual count)
  - **Less** (fewer achieved → `completedLess`, prompt for the actual count)
- During a Set:
  - **Live timer** (ticking seconds)
  - Inline edit of the current Reps or the Weight before completing the Set
- Cancel a training (with confirmation) — all of the session's previous Sets are discarded
- Training is **resilient against pop**: the user can pop out mid-Set and navigate back, the state is preserved (`TrainingCoordinatorCache`)
- When an Exercise is completed, the state of the card jumps to "completed" — visible live without a refresh thanks to `@Model` binding

## Live Activity (lock screen / Dynamic Island)

- While a training is active, the Activity appears **automatically** on the lock screen
- Three buttons: Done / More / Less
- The user can click through complete Sets **without opening the app** — it feeds directly back into the Coordinator

## Post-Exercise Feedback

- After the last Set, a feedback sheet opens automatically (two detents)
- The user can capture:
  - **Symptoms** multi-select: Pain / Dizziness / Nausea / Muscle weakness
  - **Pain region** (when "Pain" is selected) — body map with 32 regions
  - **Energy level** 1...5 (when ≥1 symptom)
  - **Note** (free text, single-line, when ≥1 symptom)
- One record per training session (`sessionId`-scoped)
- Swipe the sheet away without saving → the draft stays in memory until the Exercise is switched
- The last feedback of the same Exercise is loaded as a prefill

## Analytics & Progress

### Per-Exercise (`AnalyticsView`)

- **Hill-Chart** — visualizes an Exercise's progress over time
- **Weight-Milestones** — notable points where the Weight went up
- **Result list** — chronological list of all trainings of this Exercise
  - Delete individual Sets of an entry
  - Edit existing entries
- **Manual entry** via `AddAnalyticsEntryView` (for historical data)
- **Calendar picker** — jump to a specific date, days with data are highlighted
- **Set a goal** for the Exercise (dashed line in the chart)

### Aggregated (`TotalAnalyticsView`)

- **Overall stats** as a tile grid (number of sessions, number of completed Exercises, …)
- **Category Progress** — how much was trained per muscle group
- **Calendar** highlighting all training days across all workouts

## Schedule

- **Monthly calendar** with an indicator per training day
- **Streak banner** (current streak in days)
- **Weekly overview** (Mon–Sun with a day indicator)
- **Day detail** (which Exercises were trained on that day)
- Schedule is always **scoped to the current workout** — switching workouts reloads the data

## Profile

- Set a **nickname** — shown as "Hey {nickname}" at the top of the Profile tab
- **Body data** in an expandable card: Weight (kg), height (cm), age
- **BMI** — calculated via an external REST API, with a refresh button, in an expandable card
- **BVG tram card**: next 3 departures of tram 21 between Blockdammweg ↔ Marktstr.
  - Auto-refresh every 60 s while expanded + app `.active`
  - Swap start ↔ destination via a horizontal arrow
  - Manual refresh button
  - Offline fallback from the UserDefaults cache with a yellow stale indicator

## Platform features

- **iOS-native**, runs on iPhone (iPhone 17 Pro Max is the test sim)
- **Glass-effect UI** throughout (iOS 26 Liquid Glass), with a fallback to `.ultraThinMaterial` for older versions
- **Single-user**, everything persisted locally in SwiftData (no cloud, no account)
- **Offline-first** — the only online calls are the BMI API and the BVG tram API, both with a cache fallback
- **Swipe-back gesture** on every push (`enableSwipeBack()`)
- **Keyboard-aware**: the BottomBar hides itself automatically when the keyboard appears

## What does not exist (yet) today

- No pause/resume logic for trainings across an app restart (the cache expires with the Coordinator)
- No templates for workouts (everyone has to set up manually)
- No "1RM" calculation or other derived strength metrics
- No calorie/nutrition calculation
- No export of data (CSV / Health app / etc.)
- No input of body measurements beyond Weight/height (no waist circumference, body fat, etc.)
- No reminders/notifications for planned trainings
- No Exercise library with descriptions / instructions / videos
- No photo logs (progress photos)
- No workout plans with weekly cycles (PPL, Push/Pull, etc.)
