# 0001 — SwiftData @Model als Single Source of Truth in der UI

* Status: accepted
* Date: 2026-04-19
* Deciders: jose.nunez

## Kontext

Die App hatte zwei Refactor-Wellen für Cross-Layer-State-Sync, die das
Sync-Problem nicht gelöst haben:

- **Refactor 1**: pro-Coordinator `withObservationTracking`-Loops +
  `restartCoordinatorObservations` — fragil, viele explizite Subscriptions
- **Refactor 2** (Commit `d1e5e746`): konsolidierter `changeVersion: Int`
  Counter mit Polling-Loops in jedem ViewModel — deckt Save-Failures zu,
  ersetzt keine Domain-Events

Beide hinterließen zwei aktive Bugs:
1. `TrainingView` zeigt eine "idle"-Card ohne Play-Button nach Exercise-Finish
   (visuell stale, refresht erst beim Re-Mount).
2. `MuscleCategorySelectionView` aktualisiert die "X von Y"-Kategorie-Tiles
   erst beim Aufruf der Workout-View — nicht direkt nach Exercise-Finish.

Die strukturelle Wurzel ist **vier parallele Kopien derselben `Exercise`-Entität**:

- `ExerciseStorageService` hält `[ExerciseModel]` (SwiftData)
- `ExerciseManagementService` reicht Domain-Operationen durch
- `MuscleCategorySelectionViewModel.cardViewModels[UUID]` hält pro ID einen
  `ExerciseCardViewModel` mit eigener `Exercise`-Kopie
- `TrainingView.@State private var cardViewModel` hält noch eine Kopie

Jede dieser Quellen muss bei einer Mutation manuell synchronisiert werden.
`syncExercise(...)`, `refreshExercises()` und `changeVersion &+= 1` sind alles
Symptom-Workarounds für dieselbe strukturelle Mehrfach-Quelle.

## Optionen

- **A**: Status quo — `Int`-Counter weiterentwickeln, mehr `syncExercise`-Aufrufe
- **B**: Unidirectional data flow / Redux-Pattern (TCA o.ä.) — eigener Store, Reducer, Effects
- **C**: SwiftData `@Model` direkt als UI-SoT, `@Bindable`/`@Query` in Views
- **D**: CoreData mit `NSFetchedResultsController`-Wrapper

### Bewertung

**A** ist empirisch widerlegt. Zwei Refactor-Wellen haben das Sync-Problem nicht gelöst — die Bug-Klasse ist strukturell, nicht implementierungs-bedingt.

**B (TCA)** ist eine **valide** Architektur und löst die Bug-Klassen by-construction (unidirectional flow, gescopete Stores, deterministische Reducer-Tests). Sie wurde abgelehnt aus einem Grund: **Plattform-Richtung**. Apple's gesamte 2025/26-SwiftUI-Strategie (`@Observable`, `@Model`, `@Query`, `@Bindable`, `Observation` Framework) zielt darauf ab, **denselben Effekt** wie ein Unidirectional-Store **ohne externe Abhängigkeit** zu liefern. Pointfree (TCA-Schöpfer) selbst migriert TCA's interne Architektur auf `@Observable`. Wer heute neu startet wettet entweder auf TCA (gegen die Plattform-Richtung, mit zusätzlichem Persistence-Boilerplate weil SwiftData nicht in TCA's State-Modell aufgeht) **oder** auf `@Model`+`@Query` (mit der Plattform, zero Persistence-Boilerplate).

**D (CoreData + FRC)** wäre ein Rückschritt — `NSFetchedResultsController` ist ein UIKit-Pattern mit imperativen Updates und passt nicht zu SwiftUI's deklarativem Modell.

**C** ist die First-Party-Plattform-Antwort auf exakt das Problem das wir lösen wollen. Sie eliminiert die Bug-Klassen by-construction (eine `id` → eine Quelle), entfernt mehr Code als sie hinzufügt (T8 Cleanup), und positioniert die Codebase auf dem Pfad den Apple weiterentwickelt.

## Entscheidung

**Option C**: SwiftData `@Model` ist die Single Source of Truth in der UI.

UI-Komponenten konsumieren `@Model`-Instanzen direkt:

- **Detail-Views** halten eine konkrete `@Model`-Referenz via `@Bindable var model: ExerciseModel`
- **List-/Kollektions-Views** binden via `@Query(filter: ...) var items: [ExerciseModel]`
- **Mutationen** passieren auf der `@Model`-Instanz selbst (`model.isCompleted = true`)
- **Persistenz** via `try? context.save()` im selben MainActor-Tick — Apple's
  automatische Observation-Propagation aktualisiert alle aktiven `@Query`s und
  `@Bindable`-Views direkt.

### Eingrenzung (Scope)

- Plan bleibt **`@MainActor`-only**. Kein `@ModelActor`/Background-Mutation in
  diesem Refactor — Mitigation des bekannten Background-Context-Update-Lecks
  (siehe Stack Overflow Jan 2026, Apple Forums Apr 2025).
- Genau **ein** `ModelContext` für den UI-Pfad (`mainContext` des `ModelContainer`).
- `struct Exercise` (in `FitnessCore`) bleibt für nicht-UI-Konzerne:
  Analytics-Snapshots, Cross-Package-DTOs, pure Logic-Tests, Persistierungs-Helpers
  außerhalb des `@Model`-Lebenszyklus.
  **Neue UI darf nur `@Model`-Referenzen halten.** Kein `@State` mit
  `Exercise`-struct.
  **Bewusste Ausnahme**: `FitnessApp/Features/Training/TrainingView.swift` hält
  weiterhin `@State private var cardViewModel: ExerciseCardViewModel` mit einer
  `Exercise`-Struct-Kopie. Begründung: Der Bug-1-Trigger (UI-Flip nach
  `coordinator.finishExercise()`) existiert in dieser View strukturell nicht
  (sie navigiert weg, bevor die Mutation den Render-Pass erreicht). Migration
  per T8b deferred — Re-Aufnahme bei User-Bug-Report im Training-Detail oder
  als Aufräum-Sprint. Andere neue Views, die den gleichen "deferred"-Status
  beanspruchen wollen, müssen das hier per Patch-ADR ergänzen.

### Non-Goals

- Kein CloudKit-Sync in dieser Phase (vorbereiten via ADR-0002, aber nicht aktivieren).
- Keine Reduktion bestehender Domain-Tests die mit `struct Exercise` arbeiten.
- Keine sofortige Migration aller Views — Pilot-Migration via T5/T6/T7,
  Legacy-Cleanup in T8.

## Konsequenzen

### Positiv

- Bug-Klassen "stale Snapshot" und "VM-Cache desynchronisiert" können
  by-construction nicht existieren — es gibt nur eine Quelle pro `id`.
- Massiv weniger Code: `changeVersion`, `refreshExercises`, `syncExercise`,
  Polling-Loops und VM-Caches mit UUID-Key entfallen vollständig (T8).
- SwiftUI-native, idiomatisch — neue Team-Mitglieder finden bekannte Patterns.
- Tests können in-memory `ModelContainer` nutzen und reproduzieren genau das
  Produktionsverhalten (siehe T2 RED-Tests).

### Negativ

- Drei neue Bug-Klassen treten an die Stelle der alten zwei:
  - **Predicate-Bug** (`?.` / `!.` chains, `persistentModelID`) — Mitigation:
    T0e Skill §14 + T3 Schema-Migration (`workoutId: UUID`)
  - **Multi-Context-Lücke** — Mitigation: Single `ModelContext` (siehe Eingrenzung)
  - **View-Identity-Race** bei dynamischen `@Query`-Filtern — Mitigation: `.id()`
    auf Parent-Views (siehe T0e Skill §14d)
- `@Model`-Lifecycle und SwiftData-Quirks (Predicate-Format, `@Attribute(.unique)`,
  `.modelContainer` setup) werden zur Pflicht-Kompetenz im Team.

### Neutral

- `struct Exercise` (DTO) und `@Model class ExerciseModel` (Persistenz +
  UI-Quelle) koexistieren während und nach dem Refactor. Die DTO-Grenze ist
  bewusst und dokumentiert.
- CloudKit später möglich. Braucht aber explizite Konfliktstrategie und
  CRDT-Überlegungen — separater ADR wenn so weit.

## Wann diese Entscheidung neu bewertet werden muss

Diese ADR ist nicht in Stein. Reopen wenn **eines** der folgenden Trigger eintritt:

- **Komplexe asynchrone Flows**: Real-Time Multi-Device Editing, langlaufende
  HealthKit-Reauth-State-Machines, Apple-Watch-Live-Sync mit Konflikt-Resolution.
  TCA's deterministische `TestStore`-Tests sind hier objektiv besser als
  `@Model`+`ModelContext`-Tests.
- **Cross-Cutting Effects-Orchestration**: Wenn fünf+ Features gleichzeitig
  asynchrone Effekte (Telemetrie, Logging, Analytics, Sync, Cache-Invalidation)
  koordinieren müssen, wird ein expliziter Effects-Layer (TCA) klarer als
  verstreute `Task { ... }`-Aufrufe.
- **Apple deprecated/stagniert SwiftData**: Sehr unwahrscheinlich (Apple
  investiert seit iOS 17 jährlich), aber wenn — Migration zu TCA oder
  GRDB+Sharing-Toolkit als Alternative.
- **Predicate-Komplexität explodiert**: Wenn unsere `@Query`-Filter regelmäßig
  Joins über 3+ Modelle brauchen und SwiftData-Predicates es nicht ausdrücken
  können, ist eine Repository-Schicht mit Domain-Queries (à la Clean Architecture)
  die bessere Antwort — TCA ist dafür ein Vehikel, aber nicht zwingend.

Trigger eingetreten → ADR-0004 schreiben (Migration zu TCA), nicht still
einführen. Ein paralleler Stack ist tödlich.

## Verweise

- ADR-0002 (FitnessPersistenceUI als Schicht für SwiftData-UI-Code)
- ADR-0003 (Coordinator-Session-Vertrag — wer hält was während Training)
- Plan-Files: [`.cursor/plans/observable-models-sot/`](../../.cursor/plans/observable-models-sot/)
  (T0–T8 inkrementelle Tasks, README.md als Index)
- T0a `ui-state-sync-enforcement.mdc` (verbietet alte Counter-Pattern fortan)
- T0e Skill §14 (Predicate-Anti-Patterns als Reviewer-Pflicht)
- Apple `@Query`: <https://developer.apple.com/documentation/swiftdata/query>
- Apple `@Model`: <https://developer.apple.com/documentation/swiftdata/model()>
