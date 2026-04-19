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
- **Exports** (Stand nach T5–T8d):
  - `ExerciseCardModelView` — Variant-Resolver-Container auf `@Bindable ExerciseModel`
  - `ActiveCardModelView`, `IdleActiveCardModelView`, `InactiveCardModelView`
    — Variant-spezifische Karten-Views (alle `@_spi(PersistenceUI) public`)
  - `CategoryTileModelView` — `@Query<ExerciseModel>` mit `#Predicate` auf
    `workoutId` + `category`
  - `ExerciseModel+UI` Convenience-Properties (`hasWeight`, `displayIconName`,
    `categoryGroup`, `iconAlignment`)
  - `enum FitnessPersistenceUI { static let moduleVersion }` als nicht-SPI
    Public-Surface
  - **Nicht ausgeliefert**: `TrainingModelView` Wrapper — siehe T8b-Deferral.

### Verbleibende Verantwortungen

- `FitnessExercise` bleibt **primär** DTO-orientiert: `struct Exercise`, View-Logik
  die ohne SwiftData-Import auskommt. Konkrete Views, die als `@Query`-Host für
  `FitnessPersistenceUI`-ModelViews dienen (`MuscleCategorySelectionView`,
  `MuscleCategoryView` seit T7a/T7b/T8a), dürfen `@_spi(PersistenceUI) import
  FitnessPersistenceUI` **und** `@_spi(PersistenceUI) import FitnessStorage`
  importieren. Diese Stellen sind bewusste Boundary-Aufweichungen, im
  Code-Comment + PR-Review begründet, nicht Disziplinverstöße.
- `FitnessStorage` exponiert seine `@Model`-Klassen via `@_spi(PersistenceUI)
  public final class`. Konsumenten sind: (a) `FitnessPersistenceUI` als primäre
  Integration-Schicht, (b) `FitnessStorage`'s eigene Tests (`@_spi(PersistenceUI)
  @testable import`), (c) **vereinzelt** Feature-Views in `FitnessExercise` die
  als `@Query`-Host für ModelViews aus (a) dienen. Jede neue Stelle in (c) ist
  Review-pflichtig.

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
  ExerciseModel`) haben parallele Card/Tile-Views. Im Home/MuscleCategory-
  Subtree ist die Migration mit T7a/T7b/T8a/T8c/T8d abgeschlossen — dort
  rendert ausschließlich `FitnessPersistenceUI`. **`TrainingView` (T8b)
  bleibt bewusst auf der Legacy-`ExerciseCardContainerView`-Schiene**, da
  ihr Lebenszyklus den Bug-1-Trigger strukturell ausschließt (View navigiert
  weg, bevor `coordinator.finishExercise()` einen UI-Flip auslösen könnte).
  Re-Aufnahme bei User-Bug-Report im Training-Detail oder als Aufräum-Sprint.

### Neutral

- App-Target depends jetzt auf 7 statt 6 Packages — vernachlässigbar.
- `@_spi(PersistenceUI)` ist **nicht** sandbox-artig single-consumer. Der Marker
  zwingt jeden Importeur zu einer expliziten, im Diff sichtbaren Opt-in-Geste
  — das ist die eigentliche Schutzwirkung. Erlaubte Konsumenten:
  - `FitnessPersistenceUI` (primäre Integration-Schicht)
  - `FitnessStorage`'s eigene Tests (`@_spi(PersistenceUI) @testable import`)
  - Spezifische Views in `FitnessExercise` die als `@Query`-Host für
    ModelViews aus `FitnessPersistenceUI` dienen (T7a/T7b/T8a:
    `MuscleCategorySelectionView`, `MuscleCategoryView`)

  Jeder neue Importer in `FitnessExercise` (oder einem anderen Feature-Package)
  ist eine bewusste Boundary-Aufweichung und im Code-Review begründungspflichtig.
  PR-Diffs zeigen den Marker explizit; ein Reviewer kann die Ergänzung sofort
  sehen.

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
- T7 (inkrementelle Migration: T7-0 Cycle-Break, T7a Tile-Live, T7b Card-Live)
- T8 (Cleanup: T8a list-mode live, T8c routing live, T8d dead-code-sweep; T8b TrainingView deferred)
- Swift `@_spi`-Doc: <https://github.com/apple/swift/blob/main/docs/ReferenceGuides/UnderscoredAttributes.md#_spi>
