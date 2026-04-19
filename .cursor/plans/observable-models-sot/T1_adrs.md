# T1 — Architectural Decision Records (3 ADRs)

> **Layer**: Architektur-Dokumentation
> **Vorbedingung**: T0a-T0e (Skills/Rules/Hooks bereit)
> **Blockiert**: T2 (RED-Tests)
> **Aufwand**: ~60 min

## Ziel

Drei ADRs in `docs/adr/` als verbindliche Entscheidungen festhalten, bevor Code-Migration beginnt. Jede ADR definiert Akzeptanzkriterien die in T2-T8 verifiziert werden.

## Vorbedingung

- `docs/adr/README.md` aus T0d ist da (mit MADR-Template)
- `.cursor/hooks/checks/adr-required.sh` aus T0d ist aktiv

## Schritte

### ADR-0001 — `@Model` als UI Single Source of Truth

`Datei: docs/adr/0001-model-as-ui-source-of-truth.md`

```markdown
# 0001 — SwiftData @Model als Single Source of Truth in der UI

* Status: accepted
* Date: 2026-04-19
* Deciders: jose.nunez

## Kontext

Die App hatte zwei Refactor-Wellen für Cross-Layer-State-Sync:
- Refactor 1: pro-Coordinator `withObservationTracking`-Loops + `restartCoordinatorObservations`
- Refactor 2 (`d1e5e746`): konsolidierter `changeVersion: Int` Counter mit Polling-Loops

Beide haben das Sync-Problem nicht gelöst (zwei aktive Bugs in TrainingView und MuscleCategorySelectionView).

Wurzel: vier parallele Kopien derselben `Exercise`-Entität (Storage / ManagementService /
SelectionVM-Cache / View-`@State`) müssen manuell synchronisiert werden.

## Optionen

- **A**: Status quo — `Int`-Counter weiterentwickeln, mehr `syncExercise`-Aufrufe
- **B**: Unidirectional data flow / Redux-Pattern (TCA o.ä.)
- **C**: SwiftData `@Model` direkt als UI-SoT, `@Bindable`/`@Query`
- **D**: CoreData mit NSFetchedResultsController-Wrapper

## Entscheidung

**Option C**: SwiftData `@Model` ist die Single Source of Truth in der UI.

UI-Komponenten konsumieren `@Model`-Instanzen direkt via `@Bindable` (Detail-Views)
oder `@Query` (List-Views). Mutations passieren auf der `@Model`-Instanz selbst,
ein `try? context.save()` im selben MainActor-Tick triggert Apple's automatische
Observation-Propagation an alle aktiven `@Query`s und `@Bindable`-Views.

Eingrenzung:
- Plan bleibt **`@MainActor`-only** — kein `@ModelActor`/Background-Mutation in
  diesem Refactor (Mitigation des SO-Findings Jan 2026)
- Genau **ein** `ModelContext` für UI-Pfad (der `mainContext` des `ModelContainer`)
- `struct Exercise` (FitnessCore) bleibt für nicht-UI-Konzerne (Analytics, Cross-Package
  DTOs, pure logic Tests). Aber: **UI darf nur `@Model`-Referenzen halten**.

## Konsequenzen

Positiv:
- Bug-Klassen "stale Snapshot" und "VM-Cache desynchronisiert" können by construction
  nicht existieren (es gibt nur eine Quelle)
- Weniger Code (kein `changeVersion`, kein `refreshExercises`, kein `syncExercise`)
- SwiftUI-native, idiomatisch

Negativ:
- Bug-Klassen "Predicate-Bug", "Multi-Context-Lücke", "View-Identity-Race" sind neu
  → Mitigation in T0e-Skill und ADR-002
- `@Model`-Lifecycle und SwiftData-Quirks werden zur Pflicht-Kompetenz im Team

Neutral:
- `struct Exercise` und `@Model class ExerciseModel` koexistieren (DTO-Grenze)
- CloudKit später möglich, braucht aber explizite Konfliktstrategie (siehe ADR-002)

## Verweise

- ADR-002 (PersistenceUI-Schicht)
- ADR-003 (Coordinator-Vertrag)
- T0a ui-state-sync-enforcement.mdc (verbietet alte Counter-Pattern)
- Apple `@Query`: https://developer.apple.com/documentation/swiftdata/query
```

### ADR-0002 — FitnessPersistenceUI als SwiftData-Schicht

`Datei: docs/adr/0002-persistence-ui-package.md`

```markdown
# 0002 — FitnessPersistenceUI Package als einzige SwiftData-Import-Stelle

* Status: accepted
* Date: 2026-04-19
* Deciders: jose.nunez

## Kontext

ADR-0001 etabliert `@Model` als UI-SoT. Konsequenz: irgendwo muss
`import SwiftData` + `@Query`/`@Bindable` Code leben.

Heutige Realität:
- `ExerciseModel` ist `internal final class` in `FitnessStorage`
- Naive Variante "@Query in `FitnessExercise`" kompiliert nicht (cross-package internal)
- Alternative "alle Models public machen" öffnet die FitnessStorage-API permanent
  und macht jede Schema-Änderung zum Breaking-Change für alle Konsumenten

## Optionen

- **A**: `ExerciseModel` (und Co.) `public` machen, `FitnessExercise` importiert SwiftData
- **B**: Alle SwiftData-Views in das App-Target verschieben
- **C**: Neues SPM-Package `FitnessPersistenceUI` als einzige Stelle die
  SwiftData + Models nutzt

## Entscheidung

**Option C**: Neues Package `FitnessPersistenceUI` mit:
- `depends on`: `FitnessStorage` (für `@Model`-Klassen, evtl. via `@_spi(PersistenceUI)`),
  `FitnessCore` (für Enums, DTOs)
- `imports`: SwiftData, SwiftUI
- `exports`: `ExerciseCardModelView`, `CategoryTileModelView`, `TrainingModelView`,
  ggf. ViewModifier für `.modelContainer(...)`-Setup

`FitnessExercise` bleibt DTO-orientiert (`struct Exercise`, View-Logik die ohne
SwiftData-Import auskommt).

`FitnessStorage` exponiert seine `@Model`-Klassen kontrolliert nach
`FitnessPersistenceUI` — bevorzugt via `@_spi(PersistenceUI)` Marker statt
`public`. Das hält die generelle API-Oberfläche schmal und macht den Zugriff
explizit dokumentiert.

## Konsequenzen

Positiv:
- Klare Architektur-Schicht für SwiftData-Code (eine Stelle für CloudKit-Migration,
  Conflict-Resolution, Observation-Setup)
- `FitnessStorage` API bleibt schmal
- Tests können in-memory `ModelContainer` nutzen ohne externe Helper
- CloudKit-Future: ein bekannter Ort für `CKSyncEngine`-Integration

Negativ:
- Ein zusätzliches Package
- `FitnessExercise` und `FitnessPersistenceUI` haben für eine Übergangszeit
  parallele Card/Tile-Views (Pilot-Migration)

Neutral:
- App-Target depends jetzt auf 7 Packages statt 6

## Verweise

- ADR-0001
- T4 (Package-Setup)
- T5/T6/T7 (Pilot-Views in PersistenceUI)
```

### ADR-0003 — Coordinator-Session-Vertrag

`Datei: docs/adr/0003-coordinator-session-contract.md`

```markdown
# 0003 — Training Coordinator Session-State ist non-persistent und blocking

* Status: accepted
* Date: 2026-04-19
* Deciders: jose.nunez

## Kontext

`TrainingCoordinator.activeSessions[id].currentExercise` ist heute eine Kopie der
`Exercise`-struct, gehalten während aktiver Trainingseinheit. Mit ADR-0001 (`@Model`
als UI-SoT) entsteht ein potenzieller Konflikt:

- User startet Training für Exercise X (Coordinator hält Snapshot mit z.B. 3 Sätzen)
- User editiert Exercise X parallel (Mutation auf `@Model`-Instanz, sets = 5)
- Welche Wahrheit gilt für laufende Session? Coordinator-Snapshot oder `@Model`?

Beide Lösungen (Snapshot ignorieren / Snapshot überschreiben) führen zu UI-Bugs.

## Optionen

- **A**: Coordinator beobachtet `@Model`-Mutationen und merged sie in laufende Session
- **B**: UI blockiert Edit von Exercise X während aktiver Session
- **C**: Coordinator hält `PersistentIdentifier` statt struct-Kopie und liest live aus
  `@Model` — Mutations propagieren transparent
- **D**: Status quo — keine Garantie, dokumentiertes "don't do that"

## Entscheidung

**Option B + Konvention C-Light**:

1. Während aktiver Session für Exercise X **blockiert die UI Edit-Operationen** auf
   diesem `ExerciseModel` (Edit-Button disabled, Sheet schließt mit Hinweis).
2. Coordinator-State (`activeSessions`, `ActiveSetViewModel.completedSetCount`,
   Timer-State) ist explizit **non-persistent**: bei App-Kill mid-training geht der
   Session-Fortschritt verloren (wie heute schon).
3. Coordinator hält weiterhin nur die für Session relevanten Felder (start/end-Zeit,
   completedSets, geplante Sets aus dem Snapshot bei Session-Start). Persistierte
   Set-Resultate werden direkt auf `ExerciseModel` geschrieben (über
   `FinishExerciseUseCase` → `model.isCompleted = true; context.save()`).

## Konsequenzen

Positiv:
- Edit-while-Training-Race ausgeschlossen
- Coordinator bleibt schlank, fachlich klar abgegrenzt
- Persistenz-Pfad eindeutig: alle persistierten Mutationen laufen über `@Model` + save

Negativ:
- UI muss Edit-Block-State bereitstellen (kleine Mehrarbeit in T7-Phase)
- App-Kill mid-training verliert Session-Progress (akzeptiert, dokumentiert)

## Verweise

- ADR-0001 (`@Model` als UI-SoT)
- T7 (TrainingModelView implementiert Edit-Block)
```

### Cross-Reference

`Datei: .cursor/references/architecture-documentation.md` — Section "Architectural Decisions" anlegen oder erweitern, mit Verweisen auf alle drei ADRs.

`Datei: docs/adr/README.md` (Tabelle ergänzen):

```markdown
| 0001 | @Model als UI Single Source of Truth | accepted |
| 0002 | FitnessPersistenceUI Package | accepted |
| 0003 | Coordinator Session-State Vertrag | accepted |
```

## Definition of Done

- [ ] 3 ADR-Dateien existieren mit obigem Inhalt
- [ ] `docs/adr/README.md` Tabelle gepflegt
- [ ] `.cursor/references/architecture-documentation.md` verweist auf ADRs
- [ ] T0d-Hook lässt diesen Commit passieren (ADRs sind ja drin)
- [ ] Commit-Message verweist auf T1 + Plan

## Akzeptanzkriterien

Spätere Tasks (T2-T8) können bei Streit auf konkrete ADRs verweisen. Code-Reviews
können fordern dass jede strukturelle Abweichung von ADR-0001/2/3 entweder
upgedatet oder superseded wird.
