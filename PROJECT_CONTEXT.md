# PROJECT_CONTEXT.md — FitnessApp Code Evaluation

---

## Daten & Persistenz

### Entities und Beziehungen

```
Workout (1) ──< Exercise (N)     via storage key: workout_{workoutId}_{category}_{userId}.json
Exercise (1) ──< AnalyticsEntry (N)  via storage key: analytics_{exerciseId}_{userId}.json

Workout
├── id: UUID
├── name: String
├── createdDate / lastModified: Date
├── exerciseData: [String: Any]    ← untyped dictionary, serialized via JSONSerialization
└── selectedCategories: Set<MuscleCategoryGroup>

Exercise
├── id: UUID
├── name, weight, reps, sets, seatSetting?, noSeats, isCompleted
├── iconName, category: MuscleCategoryGroup
└── goal: Double?

AnalyticsEntry
├── id: UUID, exerciseId: UUID, date: Date
└── setProgress: [SetProgress]

SetProgress
├── status: SetStatus (.notStarted/.inProgress/.completedDone/.completedLess/.completedMore)
├── currentReps: Int, weight: Double

WeightPhase  (computed, not persisted)
MuscleCategoryGroup  enum: arms, chest, back, legs, abs
```

### Persistenz-Strategie

- **UserDefaults**: Workout-Liste (`stored_workouts`), aktuelle Workout-ID, Default-Workout-ID, userId
- **Dokumentenverzeichnis (JSON-Dateien)**:
  - Exercises pro Workout+Kategorie: `workout_{uuid}_{category}_{userId}.json`
  - Analytics pro Exercise: `analytics_{exerciseId}_{userId}.json`
  - Legacy-Exercises (pre-workout): `exercises_{category}_{userId}.json` (Migration beim ersten Zugriff)
- **Kein CoreData, kein SwiftData, kein Keychain, kein HealthKit, kein CloudKit**

### Integritaets-Risiken

- `Workout.exerciseData` ist `[String: Any]` — kein Typschutz, keine Schema-Validierung, wird via `JSONSerialization` (de)serialisiert
- Exercises und Analytics sind nur ueber `exerciseId` verknuepft, keine referentielle Integritaet — geloeschte Exercises hinterlassen verwaiste Analytics-Dateien
- `userId` wird bei erstem Zugriff generiert und in UserDefaults gespeichert; bei UserDefaults-Reset (z.B. App-Delete) werden bestehende Dateien unerreichbar (Orphaned Data)
- Kein Verschluesselung, keine Backup-Strategie
- `WorkoutStorageService.shared` ist ein Singleton mit mutablem Zustand — nicht thread-safe

---

## Architektur

### Pattern: MVVM (konsistent)

Alle Features folgen View + ViewModel (`ObservableObject` + `@Published`). Services sind separate Klassen. Kein TCA, kein Actors, kein Combine-Pipeline-basiertes Reactive.

### Dependency Map (Package-Ebene)

```
FitnessResources          (Strings/L10n)
       │
FitnessCore               (Models, Protocols)
       │
   ┌───┴───┐
FitnessStorage    FitnessUI
   │               │
   ├───────────────┤
   │               │
FitnessAnalytics  FitnessExercise  FitnessSchedule  FitnessTraining
   │               │                │                │
   └───────────────┴────────────────┴────────────────┘
                        │
                   FitnessApp (main target)
```

### Singletons und Shared State

- `WorkoutStorageService.shared` — globaler Singleton, accessed from ViewModels, Services, Views
- `SessionTrainingCache.shared` — global in-memory cache of `ActiveSetViewModel` per `MuscleCategoryGroup`
- `ExerciseStorageService()` — Klasse ohne Zustand, wird bei jedem Aufruf neu instanziiert (kein Caching, liest immer von Disk)

### Concurrency

- **Keine async/await, keine Actors, keine strukturierte Concurrency**
- Combine: nur `PassthroughSubject` in `AnalyticsViewModel` und `AnyCancellable` in `ActiveSetViewModel`/`TrainingCoordinator` fuer Timer und Observer
- `DispatchQueue.main.async` wird in `AnalyticsViewModel` fuer UI-Updates nach Save/Delete genutzt
- Alle File-I/O (`Data(contentsOf:)`, `data.write(to:)`) geschieht **synchron auf dem Main Thread**

### Navigation

- `NavigationStack` mit `NavigationPath` in `AppRouter` (EnvironmentObject)
- `NavigationDestination` enum: `.home`, `.profile`, `.totalAnalytics`, `.schedule`, `.muscleCategory(group)`, `.training(exercise, category)`
- Custom back-button handling mit `.navigationBarBackButtonHidden(true)` + `.enableSwipeBack()`
- `UIOverlayState` (EnvironmentObject) steuert Overlay-Sichtbarkeit (Menus, Sheets, Dropdowns)

---

## UI & State

### State-Inventar

| Pattern | Verwendung |
|---|---|
| `@StateObject` | ViewModels in Owner-Views (MuscleCategorySelectionView, FitnessAppApp) |
| `@ObservedObject` | ViewModels die von aussen uebergeben werden (AnalyticsView) |
| `@EnvironmentObject` | `AppRouter`, `UIOverlayState`, `WorkoutStorageService` |
| `@State` | Lokaler UI-State (showSheet, selectedDate, scrollOffset etc.) |
| `@Published` | ViewModel-Properties |
| `@Namespace` | matchedGeometryEffect in Filter-Toggle |

### Duplizierter State

- `TrainingCoordinator.currentExercise` und `ActiveSetViewModel.tracking.currentExercise` werden manuell synchronisiert (Observer + direktes Setzen) — Risiko fuer Inkonsistenz
- `WorkoutStorageService.shared.currentWorkout` wird von mehreren ViewModels direkt gelesen — kein Single Source of Truth Pattern

### Views ueber 150 Zeilen

| View | Zeilen | Bemerkung |
|---|---|---|
| `TotalAnalyticsViewModel.swift` | 728 | ViewModel, nicht View — aber enthaelt 4 verschachtelte Data Models |
| `AnalyticsView.swift` | 627 | Chart, Overlays, Goal-Setter in einer View |
| `MuscleCategorySelectionView.swift` | 626 | Haupt-Screen, 2 Modi, Overlays, Picker, Training-Integration |
| `TotalAnalyticsView.swift` | 598 | |
| `AnalyticsViewModel.swift` | 547 | Umfangreiche Berechnungslogik |
| `CustomNumberPadView.swift` | 447 | Custom Number Pad |
| `ActiveSetViewModel.swift` | 408 | Set-Tracking, Editing, QuickDone, Timer |
| `MuscleCategoryView.swift` | 354 | |
| `IdleActiveCardView.swift` | 328 | |
| `WorkoutsScreen.swift` | 312 | |

### Loading/Error-Pattern

- **Kein einheitliches Loading/Error-Pattern**: Keine Loading-States, keine Error-Anzeigen fuer den User
- File-I/O Fehler werden nur per `print()` geloggt, Rueckgabe ist leere Arrays
- Keine Skeleton-Views, keine Retry-Logik

---

## Tests

### Abdeckung

| Modul | Unit | UI | Integration |
|---|---|---|---|
| FitnessAnalytics | AnalyticsViewModelTests (308 LOC) | — | — |
| FitnessExercise | ExerciseCardViewModelTests (164 LOC), MuscleCategoryViewModelTests (210 LOC) | — | — |
| FitnessTraining | TrainingCoordinatorTests (159 LOC), SessionTrainingCacheTests (50 LOC) | — | — |
| FitnessApp | FitnessAppTests.swift (1 leerer Test) | TrainingUITests (1 Test: testFullTrainingFlow) | — |
| FitnessStorage | — | — | — |
| FitnessUI | — | — | — |
| FitnessSchedule | — | — | — |

### Mocks/Fixtures

- `MockAnalyticsStorage` (AnalyticsStoring) — in-memory
- `MockExerciseStorage` (ExerciseStoring) — in-memory
- `MockAnalyticsStorageForCoord` — minimal mock
- Helpers: `makeExercise()`, `makeEntry()`, `date()` in mehreren Test-Files (dupliziert, nicht shared)
- UI-Test-Fixtures: `ExerciseFixtures.swift`, `TestFixtures.swift` im UITests-Target

### Kritisch aber ungetestet

- **WorkoutStorageService** (Singleton, UserDefaults + File I/O, Migration) — 0 Tests
- **ExerciseStorageService** (File I/O, Migration-Logik) — 0 Tests
- **TotalAnalyticsStorageService** (aggregiert ueber alle Exercises/Workouts) — 0 Tests
- **AnalyticsStorageService** (File I/O) — 0 Tests
- Weight-basierte Analytics (totalWeightIncreases, getDailyWeightProgression, weightPhases) — nur Reps-Varianten getestet
- Workout-CRUD (create, duplicate, delete, rename) — 0 Tests
- Schedule-Feature — komplett ungetestet

---

## Risiko-Inventar

### Risiko 1: Synchroner File-I/O auf dem Main Thread

- **Trigger**: Nutzer mit vielen Exercises und langer Analytics-Historie oeffnet TotalAnalyticsView oder MuscleCategorySelectionView
- **Impact**: UI-Freeze, Watchdog-Kill bei App-Start wenn viele Dateien gelesen werden muessen. `TotalAnalyticsStorageService.loadAllAnalytics()` iteriert ueber ALLE Kategorien x ALLE Exercises und liest jede Analytics-Datei synchron.
- **Betroffene Files**: `AnalyticsStorageService.swift`, `ExerciseStorageService.swift`, `TotalAnalyticsStorageService.swift`, `TotalAnalyticsViewModel.swift`, `AnalyticsViewModel.swift`

### Risiko 2: Workout.exerciseData als [String: Any]

- **Trigger**: Speichern/Laden eines Workouts mit unerwarteten Typen in `exerciseData` (z.B. nach App-Update mit Schema-Aenderung)
- **Impact**: Stille Datenverluste — `JSONSerialization` Fehler fuehren zu leerem Dictionary. Kein Crash, aber Daten verschwinden.
- **Betroffene Files**: `Workout.swift` (Zeile 44-49, 66-68), `WorkoutStorageService.swift`

### Risiko 3: Verwaiste Analytics-Daten nach Exercise-Loeschung

- **Trigger**: Nutzer loescht ein Exercise (oder ein Workout), Analytics-Dateien bleiben auf Disk
- **Impact**: Unbegrenztes Wachstum des Dokumentenverzeichnisses. Bei neuem Exercise mit zufaellig gleicher UUID (theoretisch unmoeglich, praktisch bei Migration denkbar) falsche historische Daten.
- **Betroffene Files**: `ExerciseManagementService.swift` (kein Cleanup), `AnalyticsStorageService.swift`, `WorkoutStorageService.swift` (kein cascading delete)

### Risiko 4: Duplizierter currentExercise-State zwischen TrainingCoordinator und ActiveSetViewModel

- **Trigger**: Race condition bei schnellem Wechsel zwischen Exercises oder bei App-Background/Foreground waehrend Training
- **Impact**: UI zeigt ein Exercise, Logik arbeitet mit einem anderen. `DispatchQueue.main.async` im Observer kann die Reihenfolge umkehren.
- **Betroffene Files**: `TrainingCoordinator.swift` (Zeile 98-111, 288-301), `ActiveSetViewModel.swift`, `MuscleCategorySelectionView.swift`

### Risiko 5: Keine Fehlerbehandlung fuer den User

- **Trigger**: Jede Disk-Operation die fehlschlaegt (Speicher voll, Berechtigungsproblem, korrupte JSON-Datei)
- **Impact**: Nutzer verliert Daten ohne Feedback. Alle Fehler werden nur per `print()` geloggt. Kein Alert, kein Retry, kein Fallback.
- **Betroffene Files**: Alle Storage-Services, alle ViewModels die Storage aufrufen

---

## Implizite Entscheidungen

1. **UserDefaults als primaerer Workout-Speicher** statt File-basiert wie Exercises/Analytics — asymmetrische Persistenz-Strategie ohne dokumentierten Grund
2. **Kein HealthKit, kein CloudKit, kein iCloud-Sync** — bewusste Entscheidung fuer lokale Datenhaltung, aber keine Migration-Strategie dokumentiert falls spaeter gewuenscht
3. **Singleton-Pattern fuer WorkoutStorageService und SessionTrainingCache** statt Dependency Injection — erschwert Testbarkeit erheblich (WorkoutStorageService-Tests muessten UserDefaults mocken)
4. **Keine Versionierung des Persistenz-Schemas** — bei Modell-Aenderungen kein automatischer Migrations-Pfad (nur Legacy-Exercise-Migration vorhanden)
5. **SPM Local Packages statt Monolith** — bewusste Modularisierung, aber zirkulaere Abhaengigkeitsgefahr (FitnessUI haengt von FitnessStorage ab, was ungewoehnlich ist fuer ein UI-Package)
6. **Custom JSON-File-Persistenz statt SwiftData/CoreData** — ermoeglicht einfaches Debugging aber verzichtet auf Indizes, Migrations, Undo, Lazy Loading
7. **Kein Logging-Framework** — `print()` Statements statt strukturiertem Logging (OSLog/SwiftLog)
8. **[String: Any] in Workout.exerciseData** — Flexible Erweiterbarkeit auf Kosten von Typsicherheit, ohne Schema-Validierung

---

## Validierung (Phase 1F)

Gegenprobe gegen die 5 groessten Files bestaetigt alle obigen Aussagen. Ergaenzungen:

- **TotalAnalyticsViewModel.swift** (728 LOC): Enthaelt 4 eingebettete Data-Model-Structs (WorkoutDetailData, CategoryDetailData, ExerciseDetailData, TrainingRhythmDetailData) + 3 Helper-Structs. Diese koennten in eigene Dateien oder ins Core-Package extrahiert werden.
- **AnalyticsView.swift** (627 LOC): Mischt Chart-Rendering, Overlay-Management und Goal-Setting in einer View. Die `#if os(iOS)` / `#else` Verzweigung im TextField ist redundant (gleicher Code in beiden Branches, Zeile 454-479).
- **MuscleCategorySelectionView.swift** (626 LOC): Erstellt in `init()` DREI StateObjects und verdrahtet Closures — heavy init pattern. `MuscleCategorySelectionView` ist de facto der Main-Screen und traegt zu viel Verantwortung.
- **ActiveSetViewModel.swift** (408 LOC): 30+ bridged accessors (Zeile 86-169) die nur Weiterleitungen an State-Structs sind. Boilerplate das mit `@Observable` / Macro eliminiert werden koennte.
- **AnalyticsViewModel.swift** (547 LOC): Dupliziert die Weight-Increase-Berechnung die auch in `TotalAnalyticsViewModel` existiert (max-weight-per-day grouping pattern erscheint 4x im Projekt).

---

## Quick-Check Template (Phase 2)

Fuer jeden kuenftigen Quick Check diesen Kontext als Basis nutzen. Fokus-Bereiche:

- Synchroner File-I/O bei neuen Features pruefen
- Storage-Cleanup bei Delete-Operationen pruefen
- currentExercise-Synchronisation bei Training-Flows pruefen
- Duplizierte Berechnungslogik vermeiden
