# User Flows & Screen Map

> Wie der User sich durch die App bewegt — kein Code, nur Navigation und Affordances.

## App-Entry

Beim ersten App-Start landet der User auf dem **Workouts-Screen** ("Meine Workouts"). Es gibt **keinen Splash, keinen Onboarding-Wizard, kein Login**. Wenn ein "Default-Workout" markiert ist, wird der Stack direkt auf `Workouts → Home` vorinitialisiert (siehe `ProductionLaunchStrategy`), sodass der User sofort den Home-Screen seines Lieblings-Workouts sieht.

## BottomBar (4 Tabs, fixe Reihenfolge)

Die persistente Glass-Capsule am unteren Rand zeigt 4 Tabs (links nach rechts):

1. **Workout** (Icon: `homeIcon`) — `popToRoot()` zurück zum Workouts-Screen
2. **Analytics** (Icon: `analyticsEntry`) — Total-Analytics über alle Exercises
3. **Schedule** (Icon: `menuCalenderIcon`) — Trainingskalender + Streaks
4. **Profile** (Icon: `profileMenuIcon`) — Nickname, BMI, Tram-Karte

Daneben gibt es zwei runde Glass-Buttons:

- **Links: Back-Chevron** — `pop()` (wird ausgeblendet wenn Stack leer)
- **Rechts: Ellipsis (…)** — öffnet ein **kontextabhängiges Mini-Menü** je nach aktuellem Screen (siehe unten)

Die Tab-Auswahl wird nicht aus einem expliziten "selectedTab"-State abgeleitet, sondern aus `AppRouter.currentScene`:

| Scene                                    | Aktiver Tab |
| ---------------------------------------- | ----------- |
| `workouts`, `home`, `category`, `training` | Workout     |
| `analytics`                              | Analytics   |
| `schedule`                               | Schedule    |
| `profile`                                | Profile     |

Das heißt: Solange der User in der Workout/Training-Achse ist, bleibt der Workout-Tab hervorgehoben. Tab-Wechsel auf Analytics/Schedule/Profile ersetzen den Stack komplett (`switchTo(...)` baut den `NavigationPath` neu auf).

## Navigation Hierarchie (Workout-Achse)

```
WorkoutsScreen (root)
    │   tap auf Tile (Workout-Auswahl)
    ▼
MuscleCategorySelectionView ("Home")
    │   View-Modes: overview (5er-Kachel-Grid) | list (alle Exercises flat)
    │
    │   tap auf Kategorie-Tile (overview)        tap auf Exercise-Card "Start"
    ▼                                           ▼
MuscleCategoryView                          TrainingView
    │                                           │   live ActiveSet, Timer, FAB-Bar
    │   tap auf Exercise "Start"                │   nach letztem Satz → Feedback-Sheet
    ▼                                           ▼
TrainingView                                (Beenden → pop zurück)
```

Tab-Achsen außerhalb (jeder ersetzt den Stack):

```
TotalAnalyticsView  →  (ggf. AnalyticsView pro Exercise via Card-Tap)
ScheduleView        →  ScheduleDayDetailView (inline, kein Push)
ProfileView         →  (Card-Aufklapp inline, kein Push)
```

## Drei kanonische User-Flows

### Flow A: "Ich starte ein Training" (Tap-optimaler Pfad: 4 Taps)

1. App-Start → `WorkoutsScreen` (oder direkt `Home`, falls Default-Workout gesetzt)
2. **Tap auf Workout-Tile** → `MuscleCategorySelectionView` (Home, Overview-Mode)
3. **Tap auf Muskelgruppen-Tile** (z. B. "Brust") → `MuscleCategoryView`
4. **Tap auf Exercise-Card** (Idle-Variante) → öffnet die Card im "Active"-Mode mit Start-Button
5. **Tap auf "Start"** → `TrainingView`, ein Satz läuft, Timer tickt
6. **Tap auf Done/More/Less pro Satz** → Coordinator schreibt `SetProgress`, springt zum nächsten Satz
7. Nach letztem Satz → automatisch `FeedbackSheet` (zwei Detents) → "Save" oder "Hide"
8. **Tap auf "Beenden"** in der TrainingActionBar → `pop()` zurück zur `MuscleCategoryView`, Card ist jetzt im `completed`-State

Bei gesetztem Default-Workout reduziert sich das auf **3 Taps bis zum laufenden ersten Satz** (Workouts-Screen wird übersprungen).

### Flow B: "Ich lege eine neue Übung an" (Quick-Path via Mini-Menu)

1. Auf `MuscleCategorySelectionView` (List-Mode aktiv) → Ellipsis im BottomBar tippen
2. Mini-Menü erscheint mit "New Exercise" → tap
3. Kategorie-Auswahl (5 Tiles) → tap z. B. "Beine"
4. **`ExercisePickerView`** öffnet sich als Bottom-Sheet (`.full` editMode):
   - Name (Free-Text)
   - Gewicht (Picker)
   - Reps (Picker, 1...50)
   - Sätze (Picker, 1...10)
   - Sitzeinstellung (`ExerciseSeatPickerView`)
   - Icon (`IconPickerView`)
5. **Save** → Übung erscheint in der Kategorie-Liste

Alternativer Pfad via `MuscleCategoryView`: Mini-Menu → "Add Exercise" → gleiches Picker-Sheet, ohne Kategorie-Auswahl-Schritt.

### Flow C: "Ich schaue mir an, wie ich Fortschritte mache" (Analytics)

Es gibt zwei Eintrittspunkte:

- **Per-Übung**: Auf einer Exercise-Card → kleines Chart-Icon → öffnet `AnalyticsView` mit Hill-Chart + Weight-Milestones + Result-Liste für diese eine Übung
- **Aggregiert**: BottomBar → Analytics-Tab → `TotalAnalyticsView` mit Overall-Stats (Anzahl Sessions, abgeschlossene Übungen pro Kategorie) + Calendar-Picker für Drill-Down auf einen Tag

## Modals, Sheets & Overlays — Übersicht

Die App nutzt **vier Präsentations-Patterns**, jeweils für unterschiedliche Use-Cases:

| Pattern                    | Wofür                                         | Beispiele                                                             |
| -------------------------- | --------------------------------------------- | --------------------------------------------------------------------- |
| **Mini-Menu** (Glass-Pop)  | kontextuelle Aktionen, ausgelöst von Ellipsis | Workouts (New/Rename/Delete/Default), Home (Reset / New Exercise), MuscleCategory (Add Exercise), Training (Cancel) |
| **OverlaySheet (custom)**  | Picker-Sheets mit Action-Bar (Save/Cancel)    | `ExercisePickerView`, `ExerciseNamePickerView`, `ExerciseWeightPickerView`, `ExerciseSeatPickerView`, `IconPickerView`, `WorkoutPickerView` |
| **Native `.sheet`**         | Formulare mit Detents + Grabber               | `AnalyticsView`, `FeedbackSheetView` (Post-Exercise)                  |
| **`.fullScreenCover`**      | echte Modal-Edit-Screens                      | `CreateWorkoutView`, `RenameWorkoutView`, `AddAnalyticsEntryView`     |

### Mini-Menüs nach Scene (was der Ellipsis-Button öffnet)

| Scene      | Mini-Menü Items                                                          |
| ---------- | ------------------------------------------------------------------------ |
| `workouts` | New workout                                                              |
| `home`     | Overview-Mode: "Reset all" — List-Mode: "New Exercise" → Kategorie-Auswahl |
| `category` | Add Exercise (öffnet Picker für die aktuelle Kategorie)                  |
| `training` | Cancel Training (mit Bestätigung)                                        |
| `profile`, `schedule`, `analytics` | _kein Mini-Menü_                                       |

Außerdem hat **jedes Workout-Tile** ein eigenes Settings-Mini-Menü (Tap auf Zahnrad oder Long-Press): Duplicate / Rename / Set as Default / Delete (mit Confirm-Step).

## Live Activity (außerhalb der App)

Während ein Training aktiv ist, wird eine **iOS Live Activity** auf dem Lock-Screen / der Dynamic Island angezeigt mit drei Buttons (Done / More / Less) — der User kann den Satz dort durchklicken, ohne die App zu öffnen. Implementiert via `TrainingActivityWidget` + `AppIntent`s (`DoneIntent`, `MoreIntent`, `LessIntent`).

## Was es bewusst **nicht** gibt

- **Kein Splash-/Loading-Screen** — direkter Einstieg
- **Kein Onboarding-Wizard** — Default-Workout-Setup ist optional, App funktioniert sofort
- **Kein klassisches Hamburger-Menü oder Drawer** — alles über BottomBar + Mini-Menüs
- **Keine Push-Benachrichtigungen** (nur die Live Activity während eines aktiven Trainings)
- **Kein Search/Filter quer durch die App** — nur Workout-Picker und View-Mode-Filter (Overview/List)

## Quellen

- App-Entry: `FitnessApp/FitnessAppApp.swift`
- BottomBar: `FitnessApp/Features/BottomBar/BottomMenuBarView.swift`
- Router: `Packages/FitnessExercise/Sources/FitnessExercise/AppRouter.swift`
- Workouts-Root: `Packages/FitnessWorkouts/Sources/FitnessWorkouts/WorkoutsScreen.swift`
- Home: `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategorySelectionView.swift`
- Category: `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategoryView.swift`
- Training: `FitnessApp/Features/Training/TrainingView.swift`
- Live Activity: `FitnessApp/Shared/LiveActivity/`
