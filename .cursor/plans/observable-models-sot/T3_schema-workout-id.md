# T3 — Schema-Migration V1→V2: denormalisiertes `workoutId: UUID` auf `ExerciseModel`

> **Layer**: Schema-Anpassung — erste Anwendung von ADR-0005
> **Vorbedingung**: T2 (RED-Tests existieren)
> **Blockiert**: T4 (Package), T6 (Tile)
> **Aufwand**: ~120 min (war 60 min — ADR-0005 verlangt VersionedSchema-Setup)

## Ziel

Zwei zusammenhängende Ergebnisse:

1. **Schema-Versionierung einführen** (per ADR-0005): heutiges flaches `Schema([...])` umstellen auf `VersionedSchema` + `SchemaMigrationPlan`. T3 ist die erste Anwendung dieses Patterns; jeder zukünftige Schema-Change folgt mechanisch denselben Schritten.
2. **`ExerciseModel` bekommt `workoutId: UUID?`** als Denormalisierung der `workout` Relationship-ID. Das eliminiert die Notwendigkeit von `$0.workout?.id == X` Optional-Chain in `@Query`-Predicates (Anti-Pattern §14a, historisch broken bis iOS 17.5). Optional ist hier **Pflicht**, nicht Stilwahl: ADR-0005 § "Optionalitäts-Regel für neue Properties (Lightweight-Limit)" erklärt warum (SwiftData-Lightweight-Add validiert non-optional gegen existierende Rows bevor `didMigrate` läuft → Crash). `#Index<ExerciseModel>([\.workoutId])` wenn min target ≥ iOS 18.

Die Backfill-Logik (workoutId aus `workout?.id` ableiten) lebt als **Custom MigrationStage** zwischen `SchemaV1` und `SchemaV2` und ist via dediziertem Test verifiziert.

## Kontext aus Reviews

Devil's Advocate explizit:
> **`#Predicate { $0.workout?.id == workoutId }`**: Optional-Kette. **mehrstufige Ketten waren historisch falsch bis iOS 17.5** ... Workaround per `if let`-Umformung.

Spike:
> **Robuster in eurer Codebase:** Filter auf `id == exerciseUUID`, weil `ExerciseModel` bereits `@Attribute(.unique) var id: UUID` hat. Für Workout: gleiche Strategie.

## Schritte

### 1. SchemaV1 — den heutigen Stand als Snapshot einfrieren

Per ADR-0005 § Snapshot-Pflicht + Beziehungs-Closure-Regel:
- `ExerciseModel` ändert sich (bekommt `workoutId`) → Snapshot.
- `WorkoutModel` hat `@Relationship(inverse: \ExerciseModel.workout)` →
  muss laut Closure-Regel ebenfalls snapshot't werden, obwohl seine
  eigene Form unverändert bleibt.
- `SetProgressModel`, `AnalyticsEntryModel`, `ExerciseFeedbackModel`
  haben keine Beziehung in den ExerciseModel/WorkoutModel-Cluster
  → Live-Refs.

`Datei: Packages/FitnessStorage/Sources/FitnessStorage/Schema/SchemaV1.swift`

```swift
import SwiftData
import Foundation

/// Initial schema — die Form in der die App vor T3 zu Usern ausgeliefert wurde.
/// Snapshot nur für ExerciseModel (geändert in V2); andere Klassen sind
/// Live-Refs weil unverändert.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutModel.self,            // unverändert -> Live-Ref
            ExerciseModel.self,           // <-- Snapshot V1: SchemaV1.ExerciseModel
            SetProgressModel.self,        // unverändert -> Live-Ref
            AnalyticsEntryModel.self,     // unverändert -> Live-Ref
            ExerciseFeedbackModel.self    // unverändert -> Live-Ref
        ]
    }

    /// V1-Form von ExerciseModel: 1:1 Kopie der Live-Klasse VOR der
    /// workoutId-Einführung. Nur intern für Migration und Migrations-Tests.
    @Model
    final class ExerciseModel {
        @Attribute(.unique) var id: UUID
        var name: String
        var weight: Double
        var reps: Int
        var sets: Int
        var seatSetting: String?
        var noSeats: Bool
        var isCompleted: Bool
        var iconName: String
        var category: String
        var goal: Double?
        var sortOrder: Int
        var workout: WorkoutModel?     // Beziehung auf Live-Klasse erlaubt,
                                       // weil WorkoutModel in V1->V2 unverändert
        init(
            id: UUID, name: String, weight: Double, reps: Int, sets: Int,
            seatSetting: String? = nil, noSeats: Bool = false,
            isCompleted: Bool = false, iconName: String, category: String,
            goal: Double? = nil, sortOrder: Int = 0,
            workout: WorkoutModel? = nil
        ) {
            self.id = id
            self.name = name
            self.weight = weight
            self.reps = reps
            self.sets = sets
            self.seatSetting = seatSetting
            self.noSeats = noSeats
            self.isCompleted = isCompleted
            self.iconName = iconName
            self.category = category
            self.goal = goal
            self.sortOrder = sortOrder
            self.workout = workout
        }
    }
}
```

`SchemaV1.ExerciseModel` ist **ein eigener Swift-Type** (qualified name).
Live-Code referenziert weiterhin `ExerciseModel` ohne Präfix; nur
`SchemaV1.swift`, `MigrationPlan.swift`, und der Migrations-Test
referenzieren den Snapshot.

### 2. SchemaV2 — neues `workoutId` Property auf der Live-Klasse

`Datei: Packages/FitnessStorage/Sources/FitnessStorage/Models/ExerciseModel.swift` (Live = V2-Form):

```swift
@Model
final class ExerciseModel {
    @Attribute(.unique) var id: UUID
    /// NEU in V2. Optional weil SwiftData-Lightweight-Add für existierende
    /// Rows kein Default setzen kann (siehe ADR-0005 § Optionalitäts-Regel).
    /// `didMigrate` backfilled aus `workout?.id`. TODO: `#Index<ExerciseModel>([\.workoutId])`
    /// einführen sobald min target ≥ iOS 18.
    var workoutId: UUID?
    var name: String
    var weight: Double
    var reps: Int
    var sets: Int
    var seatSetting: String?
    var noSeats: Bool
    var isCompleted: Bool
    var iconName: String
    var category: String
    var goal: Double?
    var sortOrder: Int
    var workout: WorkoutModel?

    init(
        id: UUID, workoutId: UUID? = nil, name: String, weight: Double,
        reps: Int, sets: Int, seatSetting: String? = nil,
        noSeats: Bool = false, isCompleted: Bool = false,
        iconName: String, category: String, goal: Double? = nil,
        sortOrder: Int = 0, workout: WorkoutModel? = nil
    ) {
        self.id = id
        self.workoutId = workoutId
        self.name = name
        // ... rest wie heute
    }
}
```

`Datei: Packages/FitnessStorage/Sources/FitnessStorage/Schema/SchemaV2.swift`:

```swift
import SwiftData
import Foundation

/// Adds `workoutId: UUID?` to ExerciseModel um Optional-Chain-Predicates
/// (§14a) zu vermeiden. Optional weil Lightweight-Add (siehe ADR-0005).
/// Live-Form von ExerciseModel (= Models/ExerciseModel.swift).
/// Hybrid-Regel: keine Snapshots, weil V2 = aktueller Live-Stand.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutModel.self,
            ExerciseModel.self,           // = Live, jetzt mit workoutId
            SetProgressModel.self,
            AnalyticsEntryModel.self,
            ExerciseFeedbackModel.self
        ]
    }
}
```

### 3. MigrationPlan + Custom Stage für Backfill

`Datei: Packages/FitnessStorage/Sources/FitnessStorage/Schema/MigrationPlan.swift`

```swift
import SwiftData
import Foundation

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2_addWorkoutId]
    }

    /// V1 → V2: SwiftData fügt `workoutId` als neue Property hinzu (default-initialisiert
    /// auf UUID() durch den lightweight-Init der neuen non-optionalen Property), aber wir
    /// müssen sie aus der bestehenden `workout`-Beziehung backfillen.
    ///
    /// `didMigrate` läuft NACHDEM SwiftData die neue Spalte in V2-Form angelegt hat —
    /// hier sehen wir bereits ExerciseModel (V2) mit `workoutId == <default>` und
    /// `workout?.id == <korrekter Wert>`. Backfill ist deterministisch.
    ///
    /// Fehler-Verhalten: Wenn ein ExerciseModel keine workout-Beziehung hat (Daten-
    /// korruption aus alter Version), bleibt workoutId beim Default — wir loggen
    /// das und lassen den Eintrag bestehen statt zu crashen. Logger statt fatalError,
    /// weil eine fehlgeschlagene Migration sonst die App-Installation killt.
    static let migrateV1toV2_addWorkoutId = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let descriptor = FetchDescriptor<ExerciseModel>()
            let all = try context.fetch(descriptor)
            var fixed = 0
            var orphaned = 0
            for model in all {
                if let realId = model.workout?.id {
                    if model.workoutId != realId {
                        model.workoutId = realId
                        fixed += 1
                    }
                } else {
                    orphaned += 1
                }
            }
            if fixed > 0 || orphaned > 0 {
                let logger = Logger(subsystem: "com.fitnessapp.storage", category: "migration")
                logger.info("V1->V2: backfilled workoutId for \(fixed) rows; \(orphaned) orphans kept with default workoutId")
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
    migrationPlan: AppMigrationPlan.self,
    configurations: [config]
)
```

Identische Umstellung für `TestHelpers.makeInMemoryContainer()` (aus T2 vorhanden) — sonst gilt die Migration im In-Memory-Container nicht und Tests laufen am Production-Pfad vorbei.

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

ADR-0005 verlangt **mindestens einen dedizierten Test pro Custom MigrationStage**.
Mit dem Hybrid (Snapshot-Klasse `SchemaV1.ExerciseModel`) können wir den **echten**
Container-Wechsel V1→V2 testen, nicht nur die Backfill-Closure isoliert.

`Datei: Packages/FitnessStorage/Tests/FitnessStorageTests/Schema/MigrationV1toV2Tests.swift`

```swift
import Testing
import SwiftData
import Foundation
@testable import FitnessStorage
import FitnessCore

@Suite("V1 → V2 migration backfills workoutId from workout.id", .serialized)
@MainActor
struct MigrationV1toV2Tests {

    /// Hilfsfunktion: temporäre URL für sql-Store auf Disk, damit Container-Close
    /// + Reopen einen echten Migrations-Run auslöst (in-memory hat kein File,
    /// kann aber AUCH funktionieren — wir nutzen disk weil das der Production-Path ist).
    private func makeStoreURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "MigrationV1toV2-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "store.sqlite")
    }

    @Test("Live ExerciseModel.from sets workoutId from workout.id")
    func newModelHasWorkoutId() throws {
        let workout = WorkoutModel(id: UUID(), name: "Test")
        let exercise = Exercise(
            id: UUID(), name: "Curl", weight: 20, reps: 10, sets: 3,
            iconName: "x", category: .arms
        )
        let model = ExerciseModel.from(exercise, sortOrder: 0, workout: workout)
        #expect(model.workoutId == workout.id)
    }

    @Test("Container migration V1->V2 backfills workoutId from V1 relationship")
    func endToEndMigrationBackfills() throws {
        let url = makeStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        // 1) V1-Container öffnen, V1-Daten schreiben
        let workoutId = UUID()
        let exerciseId = UUID()
        do {
            let v1Container = try ModelContainer(
                for: SchemaV1.self,
                configurations: [ModelConfiguration(url: url)]
            )
            let ctx = ModelContext(v1Container)
            let workout = WorkoutModel(id: workoutId, name: "Test")
            let v1Exercise = SchemaV1.ExerciseModel(
                id: exerciseId, name: "Curl", weight: 20, reps: 10, sets: 3,
                iconName: "x", category: "arms", sortOrder: 0
            )
            v1Exercise.workout = workout
            ctx.insert(workout); ctx.insert(v1Exercise)
            try ctx.save()
        }

        // 2) V2-Container mit MigrationPlan öffnen — löst migrateV1toV2 aus
        let v2Container = try ModelContainer(
            for: SchemaV2.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: [ModelConfiguration(url: url)]
        )
        let ctx = ModelContext(v2Container)

        // 3) Asserts: workoutId ist gebackfilled
        let fetched = try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.id == exerciseId }
        )).first
        let unwrapped = try #require(fetched)
        #expect(unwrapped.workoutId == workoutId)
        #expect(unwrapped.workout?.id == workoutId)
    }

    @Test("Migration is idempotent — second container open changes nothing")
    func migrationIsIdempotent() throws {
        let url = makeStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let workoutId = UUID()
        let exerciseId = UUID()

        do {
            let v1 = try ModelContainer(
                for: SchemaV1.self,
                configurations: [ModelConfiguration(url: url)]
            )
            let ctx = ModelContext(v1)
            let w = WorkoutModel(id: workoutId, name: "Test")
            let e = SchemaV1.ExerciseModel(
                id: exerciseId, name: "X", weight: 0, reps: 1, sets: 1,
                iconName: "x", category: "arms"
            )
            e.workout = w
            ctx.insert(w); ctx.insert(e)
            try ctx.save()
        }

        // Erste V2-Migration
        _ = try ModelContainer(
            for: SchemaV2.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: [ModelConfiguration(url: url)]
        )
        // Zweite V2-Öffnung (keine Migration mehr nötig)
        let v2Again = try ModelContainer(
            for: SchemaV2.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: [ModelConfiguration(url: url)]
        )
        let ctx = ModelContext(v2Again)
        let unwrapped = try #require(try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.id == exerciseId }
        )).first)
        #expect(unwrapped.workoutId == workoutId)
    }

    @Test("Orphan exercise (no workout relationship) survives migration")
    func orphanedExerciseSurvivesMigration() throws {
        let url = makeStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let exerciseId = UUID()
        do {
            let v1 = try ModelContainer(
                for: SchemaV1.self,
                configurations: [ModelConfiguration(url: url)]
            )
            let ctx = ModelContext(v1)
            let orphan = SchemaV1.ExerciseModel(
                id: exerciseId, name: "Orphan", weight: 0, reps: 1, sets: 1,
                iconName: "x", category: "arms"
            )
            // Kein workout = nil
            ctx.insert(orphan); try ctx.save()
        }
        let v2 = try ModelContainer(
            for: SchemaV2.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: [ModelConfiguration(url: url)]
        )
        let ctx = ModelContext(v2)
        let fetched = try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.id == exerciseId }
        )).first
        #expect(fetched != nil)  // not deleted, not crashed
    }
}
```

### 6. Bestehende Predicates auf workoutId umstellen

`ExerciseStorageService.loadForWorkout(...)` (Production):
```swift
// vorher
predicate: #Predicate<ExerciseModel> { $0.workout?.id == workoutId }
// nachher
predicate: #Predicate<ExerciseModel> { $0.workoutId == workoutId }
```

T2-Test (`CoordinatorPersistsCompletionAfterFinishTests`) im Lockstep
mitziehen — der NOTE-Kommentar dort zeigt explizit auf diese Stelle.

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

- [ ] `Schema/SchemaV1.swift` (mit Snapshot `SchemaV1.ExerciseModel`), `Schema/SchemaV2.swift` (Live-Refs), `Schema/MigrationPlan.swift` (`AppMigrationPlan`) existieren
- [ ] `ExerciseModel.workoutId: UUID?` (Live = V2-Form). `#Index<ExerciseModel>([\.workoutId])` als TODO für iOS 18+ vermerkt; `@Attribute(.indexed)` ist iOS 18+ und für unser iOS 17-Target nicht verfügbar
- [ ] `AppMigrationPlan.migrateV1toV2_addWorkoutId` ist Custom Stage mit dokumentierter `didMigrate`-Closure und Orphan-Handling
- [ ] `StorageContainer.swift` und `TestHelpers.makeInMemoryContainer()` nutzen `ModelContainer(for: SchemaV2.self, migrationPlan: AppMigrationPlan.self, ...)`
- [ ] `ExerciseModel.from(...)` und alle Erzeuger (Recon-Schritt 4) setzen `workoutId`
- [ ] `ExerciseStorageService.loadForWorkout(...)` Predicate umgestellt auf `$0.workoutId == workoutId`
- [ ] T2-Test (`CoordinatorPersistsCompletionAfterFinishTests`) im Lockstep mitgezogen
- [ ] `MigrationV1toV2Tests` grün (Backfill + Idempotenz + Orphan + Live `from()`)
- [ ] App build grün, alle FitnessStorage-Tests grün
- [ ] Reviewing-code-changes Skill durchlaufen (Predicate §14a, AppStyle, Architektur)
- [ ] `architecture-documentation.md` Schema-Section aktualisiert (V1/V2/AppMigrationPlan)
- [ ] Stamp `.cursor/hooks/state/code-changes.stamp.md` geschrieben
- [ ] Commit-Message: "T3: introduce VersionedSchema (V1→V2) + denormalize workoutId per ADR-0005"

## Akzeptanzkriterien

- Predicate `$0.workoutId == X` ist überall möglich, kein `?.workout?.id` mehr nötig
- Schema-Versionierung etabliert: jeder zukünftige Schema-Change folgt mechanisch ADR-0005 (V_n eintragen, Stage anhängen, Test schreiben)
- Custom Stage ist idempotent und durch dedizierten Test verifiziert
- Bestehende Daten behalten korrekte Verbindungen — bei Crash mid-migration ist Re-Run safe
