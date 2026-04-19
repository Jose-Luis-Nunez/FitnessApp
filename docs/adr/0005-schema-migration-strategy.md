# 0005 — SwiftData Schema-Migration-Strategie (VersionedSchema + MigrationPlan)

* Status: accepted
* Date: 2026-04-19
* Deciders: jose.nunez

## Kontext

Bis heute hat die App **kein versioniertes Schema**. Der `ModelContainer` wird
in `Packages/FitnessStorage/.../StorageContainer.swift` aus einem flachen
`Schema([WorkoutModel.self, ExerciseModel.self, ...])` instanziiert. Apple's
SwiftData führt in diesem Fall implizite "Lightweight Migrations" durch
solange Änderungen rückwärtskompatibel sind (Property hinzufügen mit Default,
neue Entity, optionale Property entfernen). Bei nicht-trivialen Änderungen
(Property umbenennen, Typ ändern, Beziehungs-Restrukturierung, Daten
backfillen) wirft SwiftData beim Container-Bootstrap zur Laufzeit — also
**Crash beim App-Start nach Update**.

Konkreter Trigger: **T3** fügt eine neue Property `workoutId: UUID` auf
`ExerciseModel` ein und muss bestehende Einträge backfillen
(jeder `ExerciseModel.workout?.id` → eigener `workoutId`-Slot). Das ist die
**erste** Schema-Änderung die nicht trivial rückwärtskompatibel ist —
wir brauchen ab hier eine offizielle, mechanische Migrations-Strategie.

Wenn die Strategie jetzt nicht festgelegt wird, riskieren wir:

1. **Inkonsistente Migrations-Ansätze** — jeder zukünftige Schema-Change wählt
   sein eigenes Pattern (Custom in Container-Bootstrap, ad-hoc Backfill-Code,
   imperatives "lese alt → schreibe neu", …). Pro Change wieder neu erfunden.
2. **Crashes nach App-Update** — User auf Schema-Version N, App liefert
   Schema-Version N+1 ohne Migration-Plan, Container-Init wirft → App startet
   nicht mehr.
3. **Datenverlust** — naive "Property hinzufügen, Default benutzen, alte
   Beziehung ignorieren"-Migration verliert alte Beziehungs-Daten silently.
4. **Untestbare Migrations** — ohne explizite `VersionedSchema`-Stages gibt es
   nichts was man in einem Test mit kontrolliertem Vor-/Nach-Zustand
   reproduzieren kann.

## Optionen

- **A**: Status quo behalten — flaches `Schema([...])`, weiter auf implizite
  Lightweight-Migration vertrauen, Custom-Backfill-Code im
  `StorageContainer`-Init für T3 schreiben.
- **B**: `VersionedSchema` + `SchemaMigrationPlan` mit `lightweight` Stages
  einführen, aber Custom-Migrations weiter ad-hoc ohne festes Pattern.
- **C**: `VersionedSchema` + `SchemaMigrationPlan` mit dokumentiertem Pattern:
  - Jede Schema-Version ist ein `enum SchemaVN: VersionedSchema`-Namespace
  - Jede Schema-Version ist eine eigene Datei (`Packages/FitnessStorage/.../Schema/SchemaV1.swift`,
    `SchemaV2.swift`, …)
  - Migrations-Plan ist eigene Datei (`Packages/FitnessStorage/.../Schema/MigrationPlan.swift`)
  - Custom-Stages sind benannte Funktionen (`migrateV1toV2_addWorkoutId(...)`)
    mit dediziertem Test (`SchemaV1toV2MigrationTests.swift`)
- **D**: Eigene Migrations-Engine in Domain-Code (read-old-Storage, write-new-Storage)
  außerhalb von SwiftData's Migrations-API — maximale Kontrolle aber wir bauen
  das Rad nach.

### Bewertung

**A** scheidet aus weil T3 eine non-trivial Migration ist (Backfill aus
existierender Beziehung). Implizite Lightweight-Migration kann das nicht;
ad-hoc Code im Container-Bootstrap ist nicht testbar und legt das nächste
Mal denselben Pfad neu an.

**B** löst T3 aber hinterlässt das Konsistenz-Loch. Sechs Schema-Versionen
später hat das Team sechs verschiedene Migrations-Stile.

**D** verwirft SwiftData's eingebaute Mechanik. Doppelte Komplexität ohne
Gewinn — SwiftData's `MigrationPlan`-API ist genau für diesen Use-Case
entworfen und wird von Apple weiterentwickelt.

**C** ist die First-Party-Plattform-Antwort plus dokumentiertes Pattern für
Datei-Layout und Test-Pflicht. Jede Migration ist eine eigene Datei, jede hat
einen eigenen Test, das Container-Init bleibt sauber, neue Schema-Versionen
folgen mechanisch demselben Pfad.

## Entscheidung

**Option C**: `VersionedSchema` + `SchemaMigrationPlan` mit festem Datei-
Layout und Test-Pflicht pro Migrations-Stage.

### Datei-Layout (verbindlich)

```
Packages/FitnessStorage/Sources/FitnessStorage/
├── Models/                     # aktuelle Live-Modelle (re-exported aus
│   ├── WorkoutModel.swift      # SchemaVN — die "neueste" Version)
│   ├── ExerciseModel.swift
│   └── ...
├── Schema/
│   ├── SchemaV1.swift          # enum SchemaV1: VersionedSchema { ... }
│   ├── SchemaV2.swift          # enum SchemaV2: VersionedSchema { ... }
│   ├── SchemaVN.swift          # aktuelle Version (= was Models/ exportiert)
│   └── MigrationPlan.swift     # enum AppMigrationPlan: SchemaMigrationPlan
└── StorageContainer.swift      # nutzt AppMigrationPlan + SchemaVN.self
```

### Pattern pro Schema-Version

Jede `SchemaVN.swift` enthält:

1. `enum SchemaVN: VersionedSchema` mit `static var versionIdentifier`
2. `static var models: [any PersistentModel.Type]` — **Kopien** aller `@Model`-
   Klassen unter `SchemaVN.WorkoutModel`, `SchemaVN.ExerciseModel`, …
   (kein Re-Use älterer Versionen; jede Version ist self-contained)

Die "Live"-Klassen unter `Models/` sind **typealiases** auf die jüngste
Schema-Version (`typealias ExerciseModel = SchemaVN.ExerciseModel`). So
referenziert App-Code immer den aktuellen Stand, alte Versionen leben isoliert
in ihren Schema-Files.

### Pattern pro Migration

`MigrationPlan.swift` enthält:

```swift
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self /* ..., SchemaVN.self */]
    }
    static var stages: [MigrationStage] {
        [migrateV1toV2_addWorkoutId /*, ... */]
    }

    static let migrateV1toV2_addWorkoutId = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            // Backfill: jede ExerciseModel.workoutId = workout?.id ?? UUID()
        }
    )
}
```

Jede `MigrationStage` ist eine **benannte** static-Property
(`migrateVNtoVNplus1_<intent>`). Anonym im Array funktioniert auch, schadet
aber Lesbarkeit und macht Test-Referenzierung umständlich.

### Test-Pflicht (verbindlich)

Pro Custom-Stage **muss** ein Test in `Packages/FitnessStorage/Tests/.../`
existieren:

- Setup: in-memory Container mit `SchemaVN.self` (alte Version)
- Daten erzeugen die das alte Schema repräsentieren
- Container schließen, neuen Container mit `AppMigrationPlan` und Ziel-Schema öffnen
- Assert: Daten sind im neuen Schema korrekt vorhanden, Backfill-Werte stimmen,
  keine Datenverluste

Lightweight-Stages brauchen keinen Test (Apple's Mechanik ist getestet), nur
Custom-Stages.

### StorageContainer-Integration

`StorageContainer.swift` wird umgestellt von:

```swift
let schema = Schema([WorkoutModel.self, ExerciseModel.self, ...])
return try ModelContainer(for: schema)
```

auf:

```swift
return try ModelContainer(
    for: SchemaVN.self,
    migrationPlan: AppMigrationPlan.self
)
```

`Schema(...)` aus `[Model.Type]` ist eine implizite Schema-V1; einmal auf
`VersionedSchema` umgestellt bleiben alle zukünftigen Versionen mechanisch.

## Konsequenzen

### Positiv

- Jede Schema-Änderung folgt einem mechanischen Pfad. Code-Review checkt:
  "neue Datei `SchemaVN+1.swift`? `MigrationPlan.swift` updated?
  Custom-Stage hat Test?"
- Migrations sind **getestet**. Crash-nach-App-Update wird in CI gefangen,
  nicht beim ersten User.
- App-Code (`Models/`) bleibt am aktuellen Stand. Nur Schema-Files wachsen.
- Rollback / Forensik möglich: jede Schema-Version ist self-contained und
  kann isoliert geladen werden.

### Negativ

- Mehr Dateien pro `@Model`. Bei 5 aktuellen Models und jährlichen
  Schema-Changes wachsen die `Schema/`-Files linear (V1, V2, …). Mitigation:
  alte Versionen die niemand mehr migriert (alle Production-User längst auf
  V≥N) können entfernt werden — separater ADR wenn so weit, default ist
  konservativ alle behalten.
- Initiale Umstellung in T3 hat mehr Aufwand als "schnell `workoutId: UUID`
  auf `ExerciseModel`". Das ist der Preis dafür dass T4, T5, … alle billig sind.

### Neutral

- `typealias`-Indirection in `Models/` ist eine Schicht mehr aber für die
  meisten Konsumenten unsichtbar. App-Code schreibt weiter `ExerciseModel`,
  nicht `SchemaV2.ExerciseModel`.
- CloudKit-Migration (zukünftiges ADR-0004) profitiert von versioniertem Schema
  weil CloudKit-Schemas auch versioniert sind und ein 1:1-Mapping zu unserem
  `SchemaVN` erlauben.

## Wann diese Entscheidung neu bewertet werden muss

- Apple liefert eine fundamental neue Migrations-API (z.B. deklarative
  Migrations-DSL). Aktuell unwahrscheinlich; SwiftData ist ein junges
  Framework und Apple investiert weiter in `SchemaMigrationPlan`.
- Das Team migriert weg von SwiftData. Komplettes Rewrite-Szenario, eigenes ADR.

## Verweise

- ADR-0001 (Model als UI-SoT — definiert warum überhaupt `@Model` produktiv)
- ADR-0002 (FitnessPersistenceUI — wer mit dem Schema interagiert)
- T3 (Schema-Migration `workoutId: UUID` — erste echte Anwendung dieses ADRs)
- Apple `SchemaMigrationPlan`: <https://developer.apple.com/documentation/swiftdata/schemamigrationplan>
- Apple `VersionedSchema`: <https://developer.apple.com/documentation/swiftdata/versionedschema>
- Apple `MigrationStage`: <https://developer.apple.com/documentation/swiftdata/migrationstage>
- WWDC23 "Model your schema with SwiftData": <https://developer.apple.com/videos/play/wwdc2023/10195/>

Co-authored-by: Cursor <cursor@cursor.com>
