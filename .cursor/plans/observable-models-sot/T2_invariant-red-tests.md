# T2 — Invariante RED-Tests mit echtem ModelContainer

> **Layer**: Test-First (RED-Phase)
> **Vorbedingung**: T1 (ADRs)
> **Blockiert**: T3
> **Aufwand**: ~90 min

## Ziel

Zwei failing Tests schreiben die Bug 1 und Bug 2 reproduzieren, mit **echtem in-memory `ModelContainer`** statt `MockExerciseManagement`/`MockCoordinatorCache`. Beweisen damit auch dass die existierenden grünen Tests nur grün sind weil sie Mock-State manuell setzen.

Diese Tests bleiben **rot bis T7** (Pilot-Migration) und werden dann grün.

## Vorbedingung

- ADR-0001 ist commited (Test darf sich auf "Model ist UI-SoT" berufen)
- T0b skill ist da (E.2/E.3 sind die Begründung warum wir echten Container nutzen)

## Schritte

### 1. Test-Helper für echtes in-memory `ModelContainer`

`Datei: Packages/FitnessStorage/Sources/FitnessStorage/Testing/InMemoryStorageStack.swift`

(Inkl. `@_spi(Testing)` falls nötig, oder separates Test-Support-Modul)

```swift
import SwiftData
import Foundation

@MainActor
public struct InMemoryStorageStack {
    public let container: ModelContainer
    public let exerciseManagement: ExerciseManagementService
    public let exerciseStorage: ExerciseStorageService
    public let workoutStorage: WorkoutStorageService

    public init() throws {
        let schema = Schema([
            WorkoutModel.self,
            ExerciseModel.self,
            SetProgressModel.self,
            AnalyticsEntryModel.self,
            ExerciseFeedbackModel.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: [config])
        self.workoutStorage = WorkoutStorageService(container: container)
        self.exerciseStorage = ExerciseStorageService(container: container)
        self.exerciseManagement = ExerciseManagementService(
            storage: exerciseStorage,
            workoutStorage: workoutStorage
        )
    }
}
```

(Genauen Konstruktor von `ExerciseManagementService` an heutigen Stand anpassen.)

### 2. Bug-1 RED-Test: TrainingView Card-Variant nach finishExercise

`Datei: Packages/FitnessTraining/Tests/FitnessTrainingTests/CardVariantAfterFinishTests.swift`

```swift
import Testing
import SwiftData
import Foundation
@testable import FitnessTraining
@testable import FitnessStorage
@testable import FitnessExercise
import FitnessCore

@Suite("Bug 1: Card variant updates immediately after finishExercise")
@MainActor
struct CardVariantAfterFinishTests {

    @Test("After finishExercise the resolved CardVariant becomes .completed without view re-creation")
    func cardVariantUpdatesAfterFinish() async throws {
        let stack = try InMemoryStorageStack()
        try await seedSingleActiveExercise(in: stack)  // Helper: 1 Workout, 1 Exercise (3 sets, isCompleted=false)

        let exercise = try #require(stack.exerciseManagement.exercises(for: .arms).first)
        let coordinator = TrainingCoordinator(
            findCategory: { _ in .arms },
            onExerciseUpdate: { ex, cat in stack.exerciseManagement.updateExercise(ex, category: cat) },
            onExerciseReset: { ex, cat in stack.exerciseManagement.resetExercise(ex, category: cat) }
        )
        coordinator.startTraining(for: exercise)

        // simulate set completion + finish
        for _ in 0..<exercise.sets { coordinator.completeSet() }
        coordinator.finishExercise()

        // Read the canonical truth: the @Model in the container, observed via FetchDescriptor.
        let context = ModelContext(stack.container)
        var fd = FetchDescriptor<ExerciseModel>(predicate: #Predicate { $0.id == exercise.id })
        fd.fetchLimit = 1
        let model = try #require(try context.fetch(fd).first)

        // INVARIANT: persistierter Zustand reflektiert finishExercise()
        #expect(model.isCompleted == true,
                "After finishExercise, the persisted ExerciseModel must be isCompleted=true")
    }

    @Test("ExerciseCardViewModel kept as @State snapshot becomes stale after finishExercise (documents Bug 1)")
    func snapshotCardViewModelStaleAfterFinish() async throws {
        // Diese Probe dokumentiert Bug 1 explizit: simuliert was TrainingView heute tut.
        let stack = try InMemoryStorageStack()
        try await seedSingleActiveExercise(in: stack)
        let exercise = try #require(stack.exerciseManagement.exercises(for: .arms).first)

        // Snapshot-VM wie in TrainingView heute:
        let snapshotCardVM = ExerciseCardViewModel(exercise: exercise) { updated in
            stack.exerciseManagement.updateExercise(updated, category: .arms)
        }

        let coordinator = TrainingCoordinator(
            findCategory: { _ in .arms },
            onExerciseUpdate: { ex, cat in stack.exerciseManagement.updateExercise(ex, category: cat) },
            onExerciseReset: { _, _ in }
        )
        coordinator.startTraining(for: exercise)
        for _ in 0..<exercise.sets { coordinator.completeSet() }
        coordinator.finishExercise()

        // VOR Refactor 3: Snapshot bleibt stale → snapshotCardVM.exercise.isCompleted == false
        // NACH Refactor 3: TrainingView nutzt @Bindable ExerciseModel, snapshot ist gar nicht mehr Quelle
        // Dieser Assert ist deshalb der Smell-Marker:
        #expect(snapshotCardVM.exercise.isCompleted == false,
                "BEFORE T7: snapshot stays stale (this assertion documents the bug). " +
                "After T7 this test should be REMOVED, the upper test (canonical model) is the green target.")
    }
}
```

**Hinweis**: Der zweite Test ist explizit ein "Bug-Marker" und wird in T7/T8 wieder gelöscht. Der erste Test ist der dauerhafte Invariant-Test.

### 3. Bug-2 RED-Test: Tile-Count Update nach finishExercise

`Datei: Packages/FitnessExercise/Tests/FitnessExerciseTests/TileCountAfterFinishTests.swift`

```swift
import Testing
import SwiftData
import Foundation
@testable import FitnessExercise
@testable import FitnessStorage
@testable import FitnessTraining
import FitnessCore

@Suite("Bug 2: CategoryTile X-of-Y count updates immediately after finishExercise")
@MainActor
struct TileCountAfterFinishTests {

    @Test("After last exercise in category is finished, count drops to 0 of N — without view re-creation")
    func tileCountUpdatesWithoutNavigation() async throws {
        let stack = try InMemoryStorageStack()
        try await seedSingleActiveExercise(in: stack)

        let exercise = try #require(stack.exerciseManagement.exercises(for: .arms).first)

        let coordinator = TrainingCoordinator(
            findCategory: { _ in .arms },
            onExerciseUpdate: { ex, cat in stack.exerciseManagement.updateExercise(ex, category: cat) },
            onExerciseReset: { _, _ in }
        )
        coordinator.startTraining(for: exercise)
        for _ in 0..<exercise.sets { coordinator.completeSet() }
        coordinator.finishExercise()

        // Canonical truth: count active (not-completed) exercises in this category for this workout.
        let context = ModelContext(stack.container)
        let workoutId = try #require(stack.workoutStorage.currentWorkout?.id)
        var fd = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.workoutId == workoutId && $0.category == "arms" }
        )
        let models = try context.fetch(fd)

        let activeCount = models.filter { !$0.isCompleted }.count
        let totalCount = models.count

        // INVARIANT: nach finish ist 0 von 1 aktiv
        #expect(activeCount == 0)
        #expect(totalCount == 1)
    }
}
```

**Wichtig**: Dieser Test setzt voraus dass `ExerciseModel.workoutId: UUID` existiert — das ist T3. Deshalb ist die Reihenfolge T2 → T3.

**Praktischer Workaround**: Falls T2 vor T3 läuft, der Test nutzt initial den heutigen Pfad (`workout?.id == workoutId` Optional-Chain) und dokumentiert den Anti-Pattern in einem Kommentar. Nach T3 wird der Predicate auf `workoutId` umgeschrieben.

### 4. Tests laufen lassen → ROT erwartet

```bash
cd ~/Documents/repo/FitnessApp/Packages/FitnessTraining && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild test -scheme FitnessTraining \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipMacroValidation \
  -only-testing:FitnessTrainingTests/CardVariantAfterFinishTests 2>&1 | tail -40

cd ~/Documents/repo/FitnessApp/Packages/FitnessExercise && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild test -scheme FitnessExercise \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipMacroValidation \
  -only-testing:FitnessExerciseTests/TileCountAfterFinishTests 2>&1 | tail -40
```

**Erwartung**: Beide Tests **failen**. Bug-1-Test: `model.isCompleted` ist `false`
weil `FinishExerciseUseCase` heute über struct-Snapshot via `onExerciseUpdate` →
`updateExercise` → `ExerciseStorageService.saveForWorkout` läuft, was tatsächlich
persistiert. Aber: prüfen ob die FetchDescriptor-Read auf separatem Context die
Mutation sieht. Falls Test aus anderem Grund grün/rot ist, das Failure-Pattern
genau dokumentieren — das ist Teil der Erkenntnis.

### 5. Snapshot in Plan-State

`.cursor/hooks/state/code-changes.stamp.md` schreiben mit Vermerk: T2 RED-Tests
existieren, dokumentiertes Failure-Pattern.

## Definition of Done

- [ ] `InMemoryStorageStack.swift` existiert und kompiliert
- [ ] `CardVariantAfterFinishTests.swift` existiert mit beiden Tests
- [ ] `TileCountAfterFinishTests.swift` existiert
- [ ] Tests werden ausgeführt, mindestens einer ist ROT, Failure-Output dokumentiert
- [ ] Reviewing-test-quality Skill durchlaufen (kein Mock-Vertragsbruch in den neuen Tests)
- [ ] Commit-Message: "T2: invariant red tests with real in-memory ModelContainer"

## Akzeptanzkriterien

- Bug-1- und Bug-2-Verhalten wird durch automatisierte Tests reproduziert
- Tests benutzen echte Production-Verkabelung (`InMemoryStorageStack` mit echten Services)
- Kein `MockExerciseManagement.bumpVersion()`-Pattern
- Tests sind so geschrieben dass sie nach T7 (Pilot-Migration) GRÜN werden ohne weitere Anpassung
