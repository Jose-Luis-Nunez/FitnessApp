# User Flows & Screen Map

> How the user moves through the app — no code, just navigation and affordances.

## App-Entry

On first app launch the user lands on the **Workouts screen** ("My Workouts"). There is **no splash, no onboarding wizard, no login**. If a "default workout" is flagged, the stack is pre-initialized directly to `Workouts → Home` (see `ProductionLaunchStrategy`), so the user immediately sees the home screen of their favorite workout.

## BottomBar (5 tabs, fixed order)

The persistent glass capsule at the bottom edge shows 5 tabs (left to right):

1. **Workouts** (icon: `homeIcon`) — `popToRoot()` back to the Workouts screen
2. **Training** (temporary SF Symbol `dumbbell.fill`) — opens the default workout, asks for one when needed, or returns to the workout list when none exists
3. **Analytics** (icon: `analyticsEntry`) — total analytics across all Exercises
4. **Schedule** (icon: `menuCalenderIcon`) — training calendar + streaks
5. **Profile** (icon: `profileMenuIcon`) — nickname, BMI, tram card

Next to them are two round glass buttons:

- **Left: back chevron** — `pop()` (hidden when the stack is empty)
- **Right: ellipsis (…)** — opens a **context-dependent mini menu** depending on the current screen (see below)

The tab selection is not derived from an explicit "selectedTab" state, but from `AppRouter.currentScene`:

| Scene                | Active tab |
| -------------------- | ---------- |
| `workouts`           | Workouts   |
| `home`, `category`   | Training   |
| `analytics`          | Analytics  |
| `schedule`           | Schedule   |
| `profile`            | Profile    |

The workout list and the in-workout Training axis therefore remain visibly distinct. Switching to Analytics/Schedule/Profile replaces the stack completely (`switchTo(...)` rebuilds the `NavigationPath`).

## Navigation hierarchy (Workout axis)

```
WorkoutsScreen (root)
    │   tap on Tile (workout selection)
    ▼
MuscleCategorySelectionView ("Home")
    │   View-Modes: overview (5-tile grid) | list (all Exercises flat)
    │
    │   tap on category tile (overview)         tap on Exercise-Card "Start"
    ▼                                           │
MuscleCategoryView                          │
    │   tap on Exercise "Start"                │
    └──────────────────────┬────────────────────┘
                           ▼
               TrainingSheetView (overlay)
               live ActiveSet, Timer, FAB-Bar
               parent Category/List stays mounted
               Finish/Cancel/Hide → dismiss sheet
```

Tab axes outside this (each replaces the stack):

```
TotalAnalyticsView  →  (optionally AnalyticsView per Exercise via Card-Tap)
ScheduleView        →  ScheduleDayDetailView (inline, no push)
ProfileView         →  (card expand inline, no push)
```

## Three canonical user flows

### Flow A: "I start a training" (tap-optimal path: 4 taps)

1. App launch → `WorkoutsScreen` (or directly `Home`, if a default workout is set)
2. **Tap on workout tile** → `MuscleCategorySelectionView` (Home, overview mode)
3. **Tap on muscle group tile** (e.g. "Chest") → `MuscleCategoryView`
4. **Tap on Exercise-Card** (idle variant) → opens the card in "Active" mode with a Start button
5. **Tap on "Start"** → `TrainingSheetView` opens above the current Category/List screen, a Set is running, the timer ticks
6. **Tap on Done/More/Less per Set** → the Coordinator writes `SetProgress`, jumps to the next Set
7. After the last Set → automatically `FeedbackSheet` (two detents) → "Save" or "Hide"
8. **Tap on "Finish"** in the TrainingActionBar → dismiss the sheet; the still-mounted parent card is now in the `completed` state. Backdrop/grabber/Back only hide the sheet and retain the active session.

With a default workout set, this reduces to **3 taps until the first Set is running** (the Workouts screen is skipped).

### Flow B: "I create a new Exercise" (quick path via mini menu)

1. On `MuscleCategorySelectionView` (list mode active) → tap the ellipsis in the BottomBar
2. The mini menu appears with "New Exercise" → tap
3. Category selection (5 tiles) → tap e.g. "Legs"
4. **`ExercisePickerView`** opens as a bottom sheet (`.full` editMode). It is a **two-step wizard**:
   - **Step 1 — Details:** a large preview of the selected body icon — a **swipeable paged gallery** (`TabView(.page)`, bound to `selectedIconName`) when the category offers more than one icon (e.g. Abs), otherwise a static image; the Set / Reps / Weight wheels (`ExerciseWheelPickerRow`); and the Decimal-weight / Bodyweight mode cards (`ExerciseWeightModeCards`) below them. Dark (`backgroundColor`) sheet with teal accents. Action bar: **Cancel | Continue** (Continue always enabled — the name lives on step 2).
   - **Step 2 — Name & Machine (interim):** Name (`ExerciseNameBar`), Category, "No Seats" toggle and Seat Settings (Setting 1 / Setting 2), plus the delete (trash) action when editing. (Icon selection moved to the step-1 swipe gallery — no separate picker here.) Action bar: **Back | Save** (Save gated on `isFormValid`). Visual design of this step is still open.
5. **Save** (step 2) → the Exercise appears in the category list. **Back** returns to step 1; **Cancel** (either step) dismisses.

The step state is internal to `ExercisePickerView` (`ExercisePickerStep`); the public init and `ExerciseFormViewModel` are unchanged, so both call sites (`MuscleCategoryView`, `MuscleCategorySelectionView`) and the focused edit modes (`.name` / `.weight` / `.seat`) are untouched.

Alternative path via `MuscleCategoryView`: mini menu → "Add Exercise" → same picker sheet, without the category selection step.

### Flow C: "I look at how I'm making progress" (Analytics)

There are two entry points:

- **Per-Exercise**: on an Exercise-Card → small chart icon → opens `AnalyticsView` with Hill-Chart + Weight-Milestones + result list for this one Exercise
- **Aggregated**: BottomBar → Analytics tab → `TotalAnalyticsView` with overall stats (number of sessions, completed Exercises per category) + calendar picker for drill-down on a single day

### Flow D: "I add a missed workout"

1. Workouts screen → three-dot settings on the target workout → **Log Workout**
2. Choose the workout date; all active Exercises are selected and prefilled from their current configured Sets/Reps/Weight
3. Optionally deselect Exercises with the leading selection dot or open an Exercise's details to edit individual standard/bilateral results
4. **Save Workout** appends one new Analytics entry per selected Exercise and closes the sheet only after persistence succeeds; existing entries on the same day remain untouched, while a storage error leaves the editor open with an English error message

## Modals, Sheets & Overlays — Overview

The app uses **four presentation patterns**, each for a different use case:

| Pattern                    | What for                                      | Examples                                                              |
| -------------------------- | --------------------------------------------- | --------------------------------------------------------------------- |
| **Mini-Menu** (Glass-Pop)  | contextual actions, triggered by the ellipsis | Workouts (New/Rename/Delete/Default/Log Workout), Home (Reset / New Exercise), MuscleCategory (Add Exercise), Training (Cancel) |
| **OverlaySheet (custom)**  | picker sheets with an action bar (Save/Cancel) | `ExercisePickerView`, `ExerciseNamePickerView`, `ExerciseWeightPickerView`, `ExerciseSeatPickerView`, `WorkoutPickerView`, `WorkoutAnalyticsEntryView` |
| **Native `.sheet`**         | forms with detents + grabber                  | `AnalyticsView`, `FeedbackSheetView` (post-Exercise)                  |
| **`.fullScreenCover`**      | true modal edit screens                       | `CreateWorkoutView`, `RenameWorkoutView`, `AddAnalyticsEntryView`     |

### Mini menus by scene (what the ellipsis button opens)

| Scene      | Mini-Menu items                                                          |
| ---------- | ------------------------------------------------------------------------ |
| `workouts` | New workout                                                              |
| `home`     | Overview mode: "Reset all" — List mode: "New Exercise" → category selection |
| `category` | Add Exercise (opens the picker for the current category)                |
| active Training sheet above `home` / `category` | Cancel Training (with confirmation)                    |
| `profile`, `schedule`, `analytics` | _no mini menu_                                        |

In addition, **every workout tile** has its own settings mini menu (tap on the gear or long-press): Duplicate / Rename / Set as Default / Delete (with a confirm step).

## Live Activity (outside the app)

While a training is active, an **iOS Live Activity** is shown on the lock screen / Dynamic Island with three buttons (Done / More / Less) — the user can click through the Set there without opening the app. Implemented via `TrainingActivityWidget` + `AppIntent`s (`DoneIntent`, `MoreIntent`, `LessIntent`).

## What deliberately **does not** exist

- **No splash/loading screen** — direct entry
- **No onboarding wizard** — default-workout setup is optional, the app works immediately
- **No classic hamburger menu or drawer** — everything via the BottomBar + mini menus
- **No push notifications** (only the Live Activity during an active training)
- **No search/filter across the app** — only the workout picker and the view-mode filter (Overview/List)

## Sources

- App-Entry: `FitnessApp/FitnessAppApp.swift`
- BottomBar: `FitnessApp/Features/BottomBar/BottomMenuBarView.swift`
- Router: `Packages/FitnessExercise/Sources/FitnessExercise/AppRouter.swift`
- Workouts-Root: `Packages/FitnessWorkouts/Sources/FitnessWorkouts/WorkoutsScreen.swift`
- Home: `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategorySelectionView.swift`
- Category: `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategoryView.swift`
- Training: `FitnessApp/Features/Training/TrainingView.swift`
- Live Activity: `FitnessApp/Shared/LiveActivity/`
