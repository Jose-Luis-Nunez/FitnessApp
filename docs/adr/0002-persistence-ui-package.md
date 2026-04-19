# 0002 — FitnessPersistenceUI Package als einzige SwiftData-UI-Stelle

* Status: accepted
* Date: 2026-04-19
* Deciders: jose.nunez

## Kontext

ADR-0001 etabliert SwiftData `@Model` als Single Source of Truth in der UI.
Konsequenz: irgendwo muss `import SwiftData` zusammen mit `@Query`/`@Bindable`-Code
leben. Die Frage ist: in welchem Modul.

Heutige Realität:

- `ExerciseModel`, `WorkoutModel` etc. sind `internal final class` in
  `FitnessStorage` — bewusst nicht-public um die Schema-Oberfläche zu schützen.
- Naive Variante "@Query in `FitnessExercise`" kompiliert nicht: cross-package
  `internal`-Zugriff auf `ExerciseModel` ist nicht erlaubt.
- Variante "alle Models `public` machen" öffnet die `FitnessStorage`-API
  permanent. Jede Schema-Änderung wird zum Breaking-Change für alle Konsumenten,
  inklusive Test-Targets.
- Variante "alle SwiftData-Views ins App-Target verschieben" verlagert UI-Code
  zurück in den Monolith und unterläuft die SPM-Modularisierung.

## Optionen

Vier echte Optionen — jede mit unterschiedlicher Schutz-Stärke gegen "jedes
Feature-Package greift roh ans Model":

- **A**: `ExerciseModel` (und Co.) `public` machen, kein zusätzlicher Schutz
  (Vertrauen + Code-Review).
- **B**: `public` machen + SwiftLint Custom Rule die `import FitnessStorage`
  von Feature-Packages blockiert.
- **C**: Neues SPM-Package `FitnessPersistenceUI` mit `@_spi(PersistenceUI)`
  als compiler-erzwungener Zugriffsmarker auf die `@Model`-Klassen.
- **D**: `internal` Models behalten, neues Package + `public Repository`-Schicht
  in `FitnessStorage` die `@Bindable`-fähige Wrapper liefert (Adapter-Pattern).

### Bewertung

**A** scheidet aus. Vergangenheit zeigt: ohne mechanischen Schutz greifen
Features doch direkt zu, Sync-Anti-Patterns kommen zurück. Genau das wollen wir
nicht reproduzieren.

**B** (Lint-Rule) ist mittel-stark: `// swiftlint:disable next` und der Schutz
ist umgangen. Lint läuft nur in CI und im Editor — kein Compiler-Hardlock. Bei
einem 1-Person-Team noch akzeptabel, in größeren Settings ist die Versuchung
"einmalig disablen, kommt schon klar" zu groß.

**D** (Repository + Wrapper) klingt am saubersten — `internal` ist die stärkste
mögliche Schutz-Garantie. **Verworfen weil es die Plattform aushebelt**:
SwiftData's `@Query` und `@Bindable` brauchen den konkreten `@Model`-Typ.
Wrapper bauen eine Indirection-Schicht die genau die Boilerplate wieder
einführt, deren Vermeidung der ganze Sinn von SwiftData ist (`@Query<Model>`
direkt im View, automatische Property-granulare Invalidation, Two-Way-Binding).
Wir würden die Plattform-Vorteile verlieren um eine Schreibweise-Politik zu
befolgen.

**C** ist die beste Lösung. `@_spi(SPIName)` ist:

1. **Compiler-erzwungen** — ohne `@_spi(PersistenceUI) import FitnessStorage`
   ist die API für andere Module unsichtbar. Stärkere Garantie als Lint.
2. **Apple-First-Party-Pattern** — Apple selbst nutzt `@_spi` produktiv in
   `swift-package-manager`, `swift-syntax`, `swift-collections`,
   `swift-foundation`. WWDC-Sessions empfehlen es explizit für
   "module-internal but cross-module" APIs. Stabil seit Swift 5.3.
3. **PR-Review-sichtbar** — jeder Verstoß muss explizit
   `@_spi(PersistenceUI) import FitnessStorage` schreiben. Das ist im Diff
   unübersehbar, und unser Reviewer-Subagent kann das Pattern automatisch
   prüfen (zukünftiges Skill-Item).
4. **Plattform-konform** — `@Query`, `@Bindable`, automatische SwiftData-
   Invalidation funktionieren unverändert weiter. Wir verlieren keine SwiftData-
   Funktionalität.

Das `_` in `@_spi` ist Schreibweise-Politik (markiert "nicht im offiziellen
Sprach-Buch"), kein Stabilitäts-Risiko. Wenn `@_spi` jemals deprecated wird,
ist die Migration trivial: `s/@_spi(PersistenceUI)//g` an den Importen +
Visibility der Models von `@_spi(PersistenceUI) public` auf `public` ändern.
Lock-in ist niedrig, Schutz-Stärke hoch.

## Entscheidung

**Option C**: Neues Package `FitnessPersistenceUI` mit `@_spi(PersistenceUI)`
als Zugriffsmarker für `@Model`-Klassen aus `FitnessStorage`.

### Package-Spec

- **Depends on**:
  - `FitnessStorage` — für `@Model`-Klassen, kontrolliert via `@_spi(PersistenceUI)`
    Marker statt blankem `public`. So bleibt der Zugriff explizit dokumentiert.
  - `FitnessCore` — für Enums (z.B. `MuscleCategoryGroup`), DTOs (`Exercise` als
    Grenz-Typ wo nötig), Domain-Helpers
- **Imports**: `SwiftData`, `SwiftUI`
- **Exports** (initial):
  - `ExerciseCardModelView` — verbraucht `@Bindable ExerciseModel`
  - `CategoryTileModelView` — verbraucht `@Query` mit Filter auf `workoutId`
  - `TrainingModelView` — Wrapper der die zwei Pilot-Views integriert
  - ViewModifier für `.modelContainer(...)`-Setup falls separater Test-Container
    nötig

### Verbleibende Verantwortungen

- `FitnessExercise` bleibt DTO-orientiert: `struct Exercise`, View-Logik die
  ohne SwiftData-Import auskommt (z.B. `ExerciseCardViewModel` solange er
  noch existiert in der Übergangsphase, später entfernt in T8).
- `FitnessStorage` exponiert seine `@Model`-Klassen ausschließlich nach
  `FitnessPersistenceUI` via `@_spi(PersistenceUI) public final class`.
  Keine andere SPM-Library darf den `@_spi`-Marker importieren.

## Konsequenzen

### Positiv

- Klare Architektur-Schicht für SwiftData-UI-Code. Eine einzige Stelle für
  künftige Themen wie CloudKit-Migration, Conflict-Resolution, eigene
  Observation-Setups, ModelContainer-Konfiguration.
- `FitnessStorage`-API bleibt schmal — Schema-Änderungen bleiben intern,
  brechen nichts in `FitnessExercise` oder anderen DTO-Konsumenten.
- Tests können in-memory `ModelContainer` nutzen ohne externe Helper-Pakete
  einzuziehen.
- CloudKit-Future hat einen bekannten Heimatort für `CKSyncEngine`-Integration
  und Conflict-Resolution-Logik.

### Negativ

- Ein zusätzliches SPM-Package erhöht die Build-Matrix marginal.
- `FitnessExercise` (mit `ExerciseCardView` auf `struct Exercise`) und
  `FitnessPersistenceUI` (mit `ExerciseCardModelView` auf `@Bindable
  ExerciseModel`) haben für eine Übergangszeit parallele Card/Tile-Views.
  Aufgelöst in T8 (Legacy-Cleanup).

### Neutral

- App-Target depends jetzt auf 7 statt 6 Packages — vernachlässigbar.
- `@_spi`-Marker erfordert dass nur `FitnessPersistenceUI` importiert. Schutz
  ist Compiler-erzwungen (Verstoß = Compile-Error), nicht Disziplin-basiert.
  Zusätzliche Belt-and-Braces: Reviewer-Subagent prüft per neuem Skill-Item
  dass `@_spi(PersistenceUI) import` außerhalb von `FitnessPersistenceUI` nie
  vorkommt. PR-Diffs zeigen den Marker explizit, Verstoß ist sofort sichtbar.

### Lock-in / Exit-Strategie

`@_spi` ist seit Swift 5.3 stabil und wird von Apple selbst genutzt. Sollte
es jemals deprecated werden:

- Migration ist mechanisch: `@_spi(PersistenceUI) public ...` →  `public ...`
- Schutz wechselt von Compiler auf Lint (Option B oben) — ein Downgrade aber
  kein Blocker.
- Aufwand: Stunden, nicht Tage. Risiko: niedrig.

## Verweise

- ADR-0001 (begründet warum `@Model` in der UI)
- ADR-0003 (Coordinator-Vertrag — Coordinator bleibt in `FitnessTraining`,
  konsumiert keine `@Model`-Klassen direkt)
- T4 (Package-Skeleton + Workspace-Integration)
- T5 (Pilot `ExerciseCardModelView`)
- T6 (Pilot `CategoryTileModelView`)
- T7 (`TrainingModelView` Wrapper)
- Swift `@_spi`-Doc: <https://github.com/apple/swift/blob/main/docs/ReferenceGuides/UnderscoredAttributes.md#_spi>
