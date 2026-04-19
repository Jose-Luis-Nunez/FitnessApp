# T3 — Schema-Migration V1→V2: denormalisiertes `workoutId: UUID` auf `ExerciseModel`

> **Layer**: Schema-Anpassung — erste Anwendung von ADR-0005
> **Vorbedingung**: T2 (RED-Tests existieren)
> **Blockiert**: T4 (Package), T6 (Tile)
> **Aufwand**: ~120 min (war 60 min — ADR-0005 verlangt VersionedSchema-Setup)

## Ziel

Zwei zusammenhängende Ergebnisse:

1. **Schema-Versionierung einführen** (per ADR-0005): heutiges flaches `Schema([...])` umstellen auf `VersionedSchema` + `SchemaMigrationPlan`. T3 ist die erste Anwendung dieses Patterns; jeder zukünftige Schema-Change folgt mechanisch denselben Schritten.
2. **`ExerciseModel` bekommt indexed `workoutId: UUID`** als Denormalisierung der `workout` Relationship-ID. Das eliminiert die Notwendigkeit von `$0.workout?.id == X` Optional-Chain in `@Query`-Predicates (Anti-Pattern §14a, historisch broken bis iOS 17.5).

Die Backfill-Logik (workoutId aus `workout?.id` ableiten) lebt als **Custom MigrationStage** zwischen `SchemaV1` und `SchemaV2` und ist via dediziertem Test verifiziert.

## Kontext aus Reviews

Devil's Advocate explizit:
> **`#Predicate { $0.workout?.id == workoutId }`**: Optional-Kette. **mehrstufige Ketten waren historisch falsch bis iOS 17.5** ... Workaround per `if let`-Umformung.

Spike:
> **Robuster in eurer Codebase:** Filter auf `id == exerciseUUID`, weil `ExerciseModel` bereits `@Attribute(.unique) var id: UUID` hat. Für Workout: gleiche Strategie.

## Schritte

### 1. SchemaV1 — den heutigen Stand einfrieren

Per ADR-0005 ist Datei-Layout `Packages/FitnessStorage/Sources/FitnessStorage/Schema/`.

`Datei: Packages/FitnessStorage/Sources/FitnessStorage/Schema/SchemaV1.swift`

```swift
import SwiftData
import Foundation

/// Initial schema (no versioning before T3).
/// Contains ExerciseModel WITHOUT workoutId — the way it shipped to users.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutModel.self,
            ExerciseModel.self,         // current shape — no workoutId
            SetProgressModel.self,
            AnalyticsEntryModel.self,
            ExerciseFeedbackModel.self
        ]
    }
}
```

**Wichtig**: `SchemaV1` referenziert die *heutigen* `@Model`-Klassen. Da `@Model`-Typen pro Build nur in einer Form existieren können, ist die V1-Definition primär ein **Marker** für die Migration-Plan-Pipeline. Bei einem zukünftigen V3 würden V1-Snapshot-Definitionen via Conditional Compilation oder `typealias` archiviert (siehe ADR-0005 § "Wann V_n eingefroren werden muss").

### 2. SchemaV2 — neues `workoutId` Property einführen

`Datei: Packages/FitnessStorage/Sources/FitnessStorage/Models/ExerciseModel.swift`

```swift
@Model
final class ExerciseModel {
    @Attribute(.unique) var id: UUID
    @Attribute(.indexed) var workoutId: UUID  // NEU in SchemaV2 — denormalisierte Foreign-Key
    var name: String
    var category: String
    var sets: Int
    var reps: Int
    var weight: Double
    var isCompleted: Bool
    var sortOrder: Int
    var workout: WorkoutModel?
    // ...

    init(id: UUID, workoutId: UUID, name: String, ...) {
        self.id = id
        self.workoutId = workoutId
        // ...
    }
}
```

`Datei: Packages/FitnessStorage/Sources/FitnessStorage/Schema/SchemaV2.swift`

```swift
import SwiftData
import Foundation

/// Adds `workoutId: UUID` (indexed, non-optional) to ExerciseModel
/// to enable predicate-safe queries (avoids §14a Optional-Chain anti-pattern).
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV1.models   // same set; only ExerciseModel shape changed
    }
}
```

### 3. MigrationPlan + Custom Stage für Backfill

`Datei: Packages/FitnessStorage/Sources/FitnessStorage/Schema/MigrationPlan.swift`

```swift
import SwiftData
import Foundation

enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// V1 → V2: backfill ExerciseModel.workoutId from the existing workout relationship.
    /// Custom stage (not lightweight) because workoutId is non-Optional and needs derivation.
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            // ADR-0005 mandates: every custom stage MUST have a dedicated test (see § 4 below).
            let descriptor = FetchDescriptor<ExerciseModel>()
            let all = try context.fetch(descriptor)
            var fixed = 0
            for model in all {
                if let realId = model.workout?.id, model.workoutId != realId {
                    model.workoutId = realId
                    fixed += 1
                }
            }
            if fixed > 0 {
                try context.save()
            }
        }
    )
}
```

### 3a. StorageContainer auf VersionedSchema umstellen

`Datei: Packages/FitnessStorage/Sources/FitnessStorage/StorageContainer.swift`

Vor T3 (Stand heute):
```swift
let schema = Schema([WorkoutModel.self, ExerciseModel.self, ...])
let container = try ModelContainer(for: schema, configurations: [config])
```

Nach T3 (per ADR-0005):
```swift
let container = try ModelContainer(
    for: SchemaV2.self,
    migrationPlan: MigrationPlan.self,
    configurations: [config]
)
```

Identische Umstellung für `InMemoryStorageStack` (Test-Helper aus T2) — sonst gilt die Migration im In-Memory-Container nicht und Tests laufen am Production-Pfad vorbei.

### 4. Write-Pfade in den Services aktualisieren

Alle Stellen die `ExerciseModel` instanziieren oder die `workout`-Relationship setzen müssen `workoutId` mitsetzen.

```bash
rg -n 'ExerciseModel\(' Packages --glob '*.swift'
rg -n '\.workout\s*=' Packages --glob '*.swift' | rg -v Tests
```

Erwartete Stellen (Schätzung):
- `ExerciseModel.from(_:sortOrder:workout:)` — Convenience-Init
- `ExerciseStorageService.saveForWorkout(...)` (oder ähnlich) wo Models neu erzeugt werden

In `from(...)`:
```swift
static func from(_ exercise: Exercise, sortOrder: Int, workout: WorkoutModel?) -> ExerciseModel {
    ExerciseModel(
        id: exercise.id,
        workoutId: workout?.id ?? UUID(),  // <-- mitgesetzt
        // ...
    )
}
```

Falls Mutation der `workout`-Relationship später passiert → `workoutId` mitziehen.

### 5. Tests für das Schema

ADR-0005 verlangt **mindestens einen dedizierten Test pro Custom MigrationStage** der einen V_n-Container füllt, auf V_{n+1} migriert und die Invariante prüft.

`Datei: Packages/FitnessStorage/Tests/FitnessStorageTests/Schema/MigrationV1toV2Tests.swift`

```swift
import Testing
import SwiftData
import Foundation
@testable import FitnessStorage
import FitnessCore

@Suite("V1 → V2 migration backfills workoutId from workout.id")
@MainActor
struct MigrationV1toV2Tests {

    @Test("New ExerciseModel.from has workoutId == workout.id")
    func newModelHasWorkoutId() throws {
        let workout = WorkoutModel(id: UUID(), name: "Test")
        let exercise = Exercise(id: UUID(), name: "Curl", category: .arms, sets: 3, reps: 10, weight: 20, isCompleted: false)
        let model = ExerciseModel.from(exercise, sortOrder: 0, workout: workout)
        #expect(model.workoutId == workout.id)
    }

    @Test("Custom stage migrateV1toV2 backfills workoutId for legacy rows")
    func backfillCorrectsMismatch() throws {
        // Arrange: in-memory container with a row whose workoutId is the
        // "wrong" placeholder (simulates what V1 data looks like after
        // SwiftData auto-creates the new column).
        let stack = try InMemoryStorageStack()
        let ctx = ModelContext(stack.container)

        let workout = WorkoutModel(id: UUID(), name: "Test")
        let placeholder = UUID()
        let model = ExerciseModel(
            id: UUID(),
            workoutId: placeholder,        // simulates V1 default after lightweight column add
            name: "X", category: "arms", sets: 3, reps: 10, weight: 20,
            isCompleted: false, sortOrder: 0
        )
        model.workout = workout
        ctx.insert(workout); ctx.insert(model); try ctx.save()

        // Act: invoke the same closure the MigrationStage runs.
        try MigrationPlan.migrateV1toV2.didMigrate?(ctx)

        // Assert: workoutId now matches the relationship target.
        let fetched = try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.id == model.id }
        )).first
        #expect(fetched?.workoutId == workout.id)
        #expect(fetched?.workoutId != placeholder)
    }

    @Test("Stage is idempotent — running twice changes nothing on already-correct rows")
    func stageIsIdempotent() throws {
        let stack = try InMemoryStorageStack()
        let ctx = ModelContext(stack.container)
        let workout = WorkoutModel(id: UUID(), name: "Test")
        let model = ExerciseModel(
            id: UUID(), workoutId: workout.id,
            name: "X", category: "arms", sets: 1, reps: 1, weight: 0,
            isCompleted: false, sortOrder: 0
        )
        model.workout = workout
        ctx.insert(workout); ctx.insert(model); try ctx.save()

        try MigrationPlan.migrateV1toV2.didMigrate?(ctx)
        try MigrationPlan.migrateV1toV2.didMigrate?(ctx)  // second run

        let fetched = try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.id == model.id }
        )).first
        #expect(fetched?.workoutId == workout.id)
    }
}
```

### 6. Verify-T2-Bug-2-Test umstellbar

Wenn T2 einen Predicate mit `workout?.id` benutzt hatte, jetzt umstellen auf `workoutId`:
```swift
FetchDescriptor<ExerciseModel>(
    predicate: #Predicate { $0.workoutId == workoutId && $0.category == "arms" }
)
```

### 7. Tests laufen lassen

```bash
cd ~/Documents/repo/FitnessApp/Packages/FitnessStorage && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild test -scheme FitnessStorage \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipMacroValidation 2>&1 | tail -30
```

Erwartet: alle FitnessStorage-Tests grün, inklusive der neuen.

App-Build prüfen:
```bash
cd ~/Documents/repo/FitnessApp && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
xcodebuild build -scheme FitnessApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tail -20
```

### 8. Manueller Smoke-Test

Auf Simulator mit existierenden Daten:
1. App starten — `MigrationPlan` führt `migrateV1toV2` automatisch aus
2. Workout öffnen, Tile-Counts korrekt (das ändert sich erst in T6, hier nur Regression)
3. Persistenz prüfen: App killen + neu starten → keine erneute Migration (V2 ist current)

## Definition of Done

- [ ] `Schema/SchemaV1.swift`, `Schema/SchemaV2.swift`, `Schema/MigrationPlan.swift` existieren (ADR-0005-Layout)
- [ ] `ExerciseModel.workoutId: UUID` mit `.indexed` Attribut (Teil von SchemaV2)
- [ ] `MigrationPlan.migrateV1toV2` ist eine Custom Stage mit dokumentierter `didMigrate`-Closure
- [ ] `StorageContainer.swift` und `InMemoryStorageStack.swift` nutzen `ModelContainer(for: SchemaV2.self, migrationPlan: MigrationPlan.self, ...)`
- [ ] `ExerciseModel.from(...)` und alle Erzeuger setzen `workoutId`
- [ ] `MigrationV1toV2Tests` grün (mind. Backfill + Idempotenz)
- [ ] App build grün, kein Test rot der vorher grün war
- [ ] Reviewing-code-changes Skill durchlaufen (Predicate §14a, AppStyle, Architektur)
- [ ] `architecture-documentation.md` Schema-Section aktualisiert (V1/V2/MigrationPlan)
- [ ] Stamp `.cursor/hooks/state/code-changes.stamp.md` geschrieben
- [ ] adr-required.sh Hook lässt Commit passieren (Schema-Trigger → ADR-0001 + ADR-0005 als Verweise im Commit)
- [ ] Commit-Message: "T3: introduce VersionedSchema (V1→V2) + denormalize workoutId per ADR-0005"

## Akzeptanzkriterien

- Predicate `$0.workoutId == X` ist überall möglich, kein `?.workout?.id` mehr nötig
- Schema-Versionierung etabliert: jeder zukünftige Schema-Change folgt mechanisch ADR-0005 (V_n eintragen, Stage anhängen, Test schreiben)
- Custom Stage ist idempotent und durch dedizierten Test verifiziert
- Bestehende Daten behalten korrekte Verbindungen — bei Crash mid-migration ist Re-Run safe
