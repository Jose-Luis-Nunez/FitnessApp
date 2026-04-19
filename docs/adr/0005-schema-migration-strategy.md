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

Konkreter Trigger: **T3** fügt eine neue Property `workoutId: UUID?` auf
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
├── Models/                     # Live-Definitionen (= jüngste Schema-
│   ├── WorkoutModel.swift      # Version), App-Code importiert von hier
│   ├── ExerciseModel.swift
│   └── ...
├── Schema/
│   ├── SchemaV1.swift          # enum SchemaV1: VersionedSchema {
│   │                           #   nested @Model class für jede Klasse
│   │                           #   die SEITDEM geändert wurde;
│   │                           #   models = [Snapshot..., LiveRef...]
│   │                           # }
│   ├── SchemaV2.swift          # analog für V2
│   ├── SchemaVN.swift          # jüngste Version: nur Live-Refs in models
│   │                           # (keine Snapshots, weil = aktueller Stand)
│   └── MigrationPlan.swift     # enum AppMigrationPlan: SchemaMigrationPlan
└── StorageContainer.swift      # nutzt AppMigrationPlan + SchemaVN.self
```

### Pattern pro Schema-Version

Jede `SchemaVN.swift` enthält:

1. `enum SchemaVN: VersionedSchema` mit `static var versionIdentifier`
2. `static var models: [any PersistentModel.Type]` — die Liste aller
   persistierten `@Model`-Klassen wie sie in **dieser** Schema-Version
   aussehen.

Welche Klassen davon eine **eigene Snapshot-Definition** brauchen, regelt
die Snapshot-Pflicht (siehe nächster Abschnitt).

### Snapshot-Pflicht (Hybrid-Regel)

Eine `@Model`-Klasse muss **nur dann** als Snapshot-Kopie unter
`SchemaVN.<Klasse>` geschrieben werden, **wenn sich ihre persistierte Form**
in einer späteren Schema-Version **geändert hat** (Property hinzugefügt
non-optional, Property entfernt, Typ geändert, Beziehung umstrukturiert,
Index/Unique-Constraint geändert).

Solange eine Klasse über mehrere Schema-Versionen **identisch** bleibt,
referenzieren `SchemaV{N-1}.models` und `SchemaVN.models` denselben
Live-Type aus `Models/`.

**Mechanik beim nächsten Schema-Change**:

1. Identifiziere die zu ändernde(n) Klasse(n).
2. **Snapshot ihre AKTUELLE (= V{N})-Form** unter
   `Schema/SchemaV{N}.swift` als nested `@Model class`. Inhalt =
   1:1 Kopie der `Models/<Klasse>.swift` *bevor* du sie änderst.
3. Editiere `Models/<Klasse>.swift` auf die neue Form (= `V{N+1}`).
4. Erstelle `Schema/SchemaV{N+1}.swift`. `models:` referenziert die
   neuen Live-Klassen plus alle unveränderten Live-Klassen.
5. `SchemaV{N}.models:` ersetzt den Eintrag der geänderten Klasse durch
   den Snapshot (`SchemaV{N}.<Klasse>.self`); unveränderte Klassen
   bleiben Live-Refs.
6. Erweitere `MigrationPlan.swift` um `migrateV{N}toV{N+1}_<intent>`.
7. Schreibe Test (siehe Test-Pflicht).

**Beziehungs-Closure-Regel**: Eine `@Relationship` (inverse oder direkt)
referenziert immer einen konkreten Swift-Type. Wenn die geänderte
Klasse `Z` mit Beziehung von Klasse `A` ist (`A` hält `[Z]` oder
`A: \Z`-inverse), dann sind in V_old und V_new **zwei distincte**
Swift-Typen für `Z` aktiv. SwiftData kann eine Live-Klasse `A` nicht
gleichzeitig auf zwei Typen für `Z` registrieren — also muss **`A`
ebenfalls snapshot't werden**, auch wenn `A` selbst feldgleich
bleibt. Der Snapshot ist dann eine 1:1-Kopie der Live-Klasse, deren
einzige Funktion ist, in V_old auf den V_old-`Z`-Typ zu zeigen.

Reine FK-Felder (`var fooId: UUID`) sind **keine** Beziehung im
Sinne dieser Regel und triggern den Closure-Snapshot nicht.

Folge dieser Regel rekursiv bis kein Klassen-Cluster mehr Verbindungen
über die "geänderte" Menge hinweg hat. Andere `@Model`-Klassen ohne
Beziehung in diesen Cluster bleiben Live-Refs.

### Begründung der Hybrid-Regel

Die strikte "alle Klassen jeder Version snapshotten"-Variante ist
korrekt aber teuer: bei 5 Models und 4 Migrations-Schritten ergibt sie
20 Snapshot-Definitionen, davon 15 Klone identischer Code. Die
"alle Klassen sind Live-Refs in allen Versionen"-Variante ist billig
aber bricht den Migrations-Test (man kann V1-Daten mit V2-Form nicht
erzeugen, also auch nicht testweise migrieren).

Die Hybrid-Regel snapshot't **nur die tatsächlich geänderten Klassen**.
Diff-Cost = Cost-of-Change. Die Reviewability bleibt erhalten
("Welche Klasse hat sich geändert?" = "welche hat einen Snapshot in
diesem Commit?"), und Migration-Tests bleiben schreibbar weil V_old
und V_new für die geänderte Klasse zwei distincte Swift-Types sind.

Apple's WWDC23 SampleTrips folgt exakt diesem Hybrid (Trip wird
snapshot't weil Trip sich ändert; LivingAccommodation und
BucketListItem bleiben Live-Refs zwischen V1/V2 weil sie unverändert
sind).

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
            // Backfill: jede ExerciseModel.workoutId = workout?.id
            // (orphans bleiben mit nil, werden beim nächsten Save überschrieben)
        }
    )
}
```

Jede `MigrationStage` ist eine **benannte** static-Property
(`migrateVNtoVNplus1_<intent>`). Anonym im Array funktioniert auch, schadet
aber Lesbarkeit und macht Test-Referenzierung umständlich.

### Optionalitäts-Regel für neue Properties (Lightweight-Limit)

**Regel**: Eine neue Property die in `V_old` nicht existiert und in `V_new`
hinzugefügt wird, **muss als Optional deklariert sein** (`var foo: Bar?`),
auch wenn sie semantisch nie `nil` sein darf.

**Begründung (mit Apple-Doku belegt)**:

SwiftData führt vor jeder Custom-`MigrationStage` einen impliziten
Lightweight-Schritt durch. Der ergänzt die persistierten Tabellen um die
neue Spalte **bevor** `willMigrate`/`didMigrate` läuft. Dieser Schritt
validiert die Spalte gegen das neue Schema und failt mit
`Validation error missing attribute values on mandatory destination
attribute` wenn die Spalte non-optional ist und für existierende Rows
kein Wert da ist. Das `init`-Default greift hier nicht — das gilt nur
für **neu insertierte** Objekte, nicht für die Migration bestehender Rows.

Belegt durch:

- Apple Developer Forum thread "SwiftData Migration Error: Missing
  Attribute Values" — Apple-Engineer-Antwort empfiehlt Optional + custom
  stage für Backfill: <https://developer.apple.com/forums/thread/746577>
- Apple Developer Forum thread "Migrating schemas in SwiftData":
  <https://developer.apple.com/forums/thread/764236>

**Alternativen die bewertet und verworfen wurden**:

| Variante | Verworfen weil |
|---|---|
| Property non-optional + `init`-Default | Crash beim ersten Container-Open nach Update (init greift bei Migration nicht) |
| 3-Schema-Kette V1 → V1.5 (optional) → V2 (non-optional) | Doppelter Snapshot/Stage/Test-Aufwand pro FK-Field; rebenefit nur kosmetisch (`UUID` statt `UUID?` im Live-Code) |
| Delete-and-recreate in `didMigrate` | Bricht externe Referenzen (andere Models halten die alte ID), Insertion-Order-abhängig, korrumpiert Beziehungen |

**Predicate-Safety bei `UUID?`-Vergleich**: Der §14a-Anti-Pattern
(`reviewing-code-changes` Skill) verbietet **Optional-Chains** in
`#Predicate` (`$0.relation?.id == foo`), nicht den direkten Vergleich
zweier Optionals. `$0.workoutId == workoutId` mit
`workoutId: UUID?` vs Funktionsparameter `UUID` kompiliert in einen
flachen SQL-Vergleich (`WHERE workoutId = ?`), nicht in einen Join.
Das ist **kein** Anti-Pattern und voll indexable.

**Konsequenz für Production-Code**: Production-Save-Pfade
(`ExerciseModel.from(_:sortOrder:workout:)`, alle direkten Erzeuger)
müssen weiter den realen `workoutId` setzen. Der `nil`-Zustand existiert
nur transient während `didMigrate` und für orphans (rows ohne
`@Relationship`-Partner). Reviewer prüfen: jeder neue Erzeuger ruft
den Helper oder setzt `workoutId` explizit.

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

- Bei jedem Schema-Change muss der Engineer **vor** der Code-Änderung
  einen Snapshot der aktuellen Form schreiben (Hybrid-Regel Schritt 2).
  Vergisst er das, ist der Migrations-Test nicht schreibbar und der
  pre-commit Hook (adr-required) blockt den Commit. Das ist Disziplin-
  Aufwand; der Hybrid macht ihn aber so klein wie möglich (nur die
  tatsächlich geänderte Klasse).
- Initiale Umstellung in T3 hat mehr Aufwand als "schnell `workoutId: UUID`
  auf `ExerciseModel`". Das ist der Preis dafür dass T4, T5, … alle billig sind.

### Neutral

- App-Code referenziert weiter `ExerciseModel`, `WorkoutModel` etc. ohne
  Schema-Präfix — die `Models/`-Dateien sind die Live-Definitionen
  (= jüngste Version). Snapshot-Klassen unter `SchemaVN.<Name>` werden
  nur intern in Schema/Migration/Test-Code referenziert.
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
