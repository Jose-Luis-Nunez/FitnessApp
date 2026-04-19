# T7 — Pilot: `TrainingModelView` Wrapper + Integration in App

> **Layer**: Pilot-Migration (Integration)
> **Vorbedingung**: T5 (Card), T6 (Tile)
> **Blockiert**: T8 (Cleanup)
> **Aufwand**: ~120 min

## Ziel

`TrainingModelView` als neuer Top-Level Trainings-Screen in `FitnessPersistenceUI`, der die `Exercise`-struct (vom Router übergeben) intern via UUID-`@Query` zu einem `ExerciseModel` resolved und an `ExerciseCardModelView` weitergibt. Außerdem `MuscleCategorySelectionView` umstellen auf `CategoryTileModelView`. Macht **beide** Bug-Tests aus T2 grün.

Per ADR-0002 + Spike: Router bleibt bei `Exercise`-struct (keine `PersistentIdentifier`-Übergabe). Resolution passiert in der View.

## Schritte

### 1. TrainingModelView

`Datei: Packages/FitnessPersistenceUI/Sources/FitnessPersistenceUI/TrainingModelView.swift`

```swift
import SwiftUI
import SwiftData
@_spi(PersistenceUI) import FitnessStorage
import FitnessCore
import FitnessTraining
import FitnessExercise

public struct TrainingModelView: View {
    public let exercise: Exercise          // vom Router
    public let category: MuscleCategoryGroup

    @Query private var matches: [ExerciseModel]
    @Environment(\.modelContext) private var modelContext

    // Coordinator-State (per ADR-0003 non-persistent, blocking edits during session)
    @State private var trainingCoordinator: TrainingCoordinator?

    public init(exercise: Exercise, category: MuscleCategoryGroup) {
        self.exercise = exercise
        self.category = category

        let id = exercise.id
        var fd = FetchDescriptor<ExerciseModel>(predicate: #Predicate { $0.id == id })
        fd.fetchLimit = 1
        _matches = Query(fd)
    }

    public var body: some View {
        Group {
            if let model = matches.first {
                content(for: model)
            } else {
                // Edge-case: model gelöscht während View aktiv. Bewusst leerer Zustand.
                EmptyTrainingPlaceholder()
                    .onAppear { /* navigate back via router */ }
            }
        }
    }

    @ViewBuilder
    private func content(for model: ExerciseModel) -> some View {
        ExerciseCardModelView(
            model: model,
            activeExerciseId: trainingCoordinator?.activeExerciseId,
            isActiveSetVisible: trainingCoordinator?.isActiveSetVisible ?? false,
            onTap: { /* same as today */ },
            onActivate: {
                ensureCoordinator(for: model).startTraining(for: model.toDomain())
            },
            onLog: {
                ensureCoordinator(for: model).completeSet()
            }
        )
        // Per ADR-0003: Edit blocked während Session. UI-Hint:
        .disabled(/* edit-mode AND coordinator.isActiveSession */ false)
    }

    private func ensureCoordinator(for model: ExerciseModel) -> TrainingCoordinator {
        if let c = trainingCoordinator { return c }
        let c = TrainingCoordinator(
            findCategory: { _ in category },
            onExerciseUpdate: { exercise, cat in
                // Mutation läuft IMMER über @Model + save (ADR-0001)
                let id = exercise.id
                var fd = FetchDescriptor<ExerciseModel>(predicate: #Predicate { $0.id == id })
                fd.fetchLimit = 1
                if let m = try? modelContext.fetch(fd).first {
                    m.isCompleted = exercise.isCompleted
                    m.weight = exercise.weight
                    m.reps = exercise.reps
                    m.sets = exercise.sets
                    try? modelContext.save()
                }
            },
            onExerciseReset: { exercise, cat in
                let id = exercise.id
                var fd = FetchDescriptor<ExerciseModel>(predicate: #Predicate { $0.id == id })
                fd.fetchLimit = 1
                if let m = try? modelContext.fetch(fd).first {
                    m.isCompleted = false
                    try? modelContext.save()
                }
            }
        )
        trainingCoordinator = c
        return c
    }
}

private struct EmptyTrainingPlaceholder: View {
    var body: some View {
        ContentUnavailableView("Übung nicht gefunden", systemImage: "exclamationmark.triangle")
    }
}
```

### 2. NavigationDestination/Router umstellen

`Datei: Packages/FitnessExercise/Sources/FitnessExercise/NavigationDestination.swift` — `.training` bleibt unverändert (`Exercise`, `MuscleCategoryGroup`).

`Datei: FitnessApp/FitnessAppApp.swift` (oder wo NavigationDestination dispatched wird) — Switch ändern:

```swift
case .training(let exercise, let category):
    TrainingModelView(exercise: exercise, category: category)  // statt TrainingView
```

Alte `TrainingView` bleibt im Code (Cleanup in T8), nur nicht mehr aufgerufen.

### 3. MuscleCategorySelectionView umstellen

`Datei: Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategorySelectionView.swift`

Tile-Body ersetzen — aber Achtung: `MuscleCategorySelectionView` lebt im
`FitnessExercise`-Package, das **nicht** SwiftData importiert. Lösung:
`MuscleCategorySelectionView` selbst nach `FitnessPersistenceUI` verschieben, ODER
ein Wrapper-Pattern.

**Empfehlung**: View-Body bleibt in FitnessExercise, aber das Tile-Rendering wird per
generischem View-Builder-Slot von außen (App-Target oder PersistenceUI) injiziert.

Pragmatisch für T7:

`Datei: Packages/FitnessPersistenceUI/Sources/FitnessPersistenceUI/MuscleCategorySelectionModelView.swift`

```swift
import SwiftUI
@_spi(PersistenceUI) import FitnessStorage
import FitnessCore
import FitnessExercise

public struct MuscleCategorySelectionModelView: View {
    public let workoutId: UUID
    @Bindable public var viewModel: MuscleCategorySelectionViewModel

    public init(workoutId: UUID, viewModel: MuscleCategorySelectionViewModel) {
        self.workoutId = workoutId
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: AppStyle.Spacing.tileGrid) {
                ForEach(MuscleCategoryGroup.allCases, id: \.self) { group in
                    CategoryTileModelView(
                        group: group,
                        workoutId: workoutId,
                        hasActiveSetForCategory: viewModel.hasActiveSetForCategory(group),
                        onTap: { viewModel.handleTap(for: group) }
                    )
                    .id("\(workoutId.uuidString)-\(group.rawValue)")  // §14d Mitigation
                }
            }
        }
    }
}
```

App-Target-Aufrufer (Workouts-Screen) statt `MuscleCategorySelectionView` jetzt `MuscleCategorySelectionModelView`.

`MuscleCategorySelectionViewModel` wird **nur noch für Coordinator-State + Navigation** verwendet — keine `cardViewModels`/`exercisesByCategory` Daten-Mirror mehr. Cleanup in T8.

### 4. Manuelle Verifikation der zwei Original-Bugs

Auf Simulator:
1. App starten, in Workout gehen, Übung X auswählen, alle Sets completen, finish
2. **Bug 1 fixed**: Card zeigt sofort "completed" Variant (kein zurück-und-wieder-rein nötig)
3. Zurück zu MuscleCategorySelectionView
4. **Bug 2 fixed**: "X of Y"-Count ist sofort aktualisiert (kein zur Workout-View und zurück nötig)

### 5. T2 Bug-Tests jetzt grün

```bash
# Re-run der RED-Tests aus T2:
cd ~/Documents/repo/FitnessApp/Packages/FitnessTraining && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild test -scheme FitnessTraining \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipMacroValidation \
  -only-testing:FitnessTrainingTests/CardVariantAfterFinishTests 2>&1 | tail -30

cd ~/Documents/repo/FitnessApp/Packages/FitnessExercise && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild test -scheme FitnessExercise \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipMacroValidation \
  -only-testing:FitnessExerciseTests/TileCountAfterFinishTests 2>&1 | tail -30
```

Erwartet: `cardVariantUpdatesAfterFinish` und `tileCountUpdatesWithoutNavigation` GRÜN.

Der `snapshotCardViewModelStaleAfterFinish`-Marker-Test bleibt grün (er dokumentiert ja den alten Bug — unverändert weil alter `TrainingView` immer noch existiert). Wird in T8 gelöscht.

### 6. Full Test Suite

```bash
# scripts/fast-test.sh ausführen
.cursor/scripts/fast-test.sh 2>&1 | tail -20
```

Alles grün, vor allem:
- Keine FitnessExerciseTests die das alte Mock-Pattern nutzten brechen (sie laufen weiter weil alte VMs/Views noch existieren)

### 7. Reviewing-code-changes Skill (Pflicht — viele Swift-Files geändert)

Reviewer-Subagent über die T7-Änderungen laufen lassen. Mindestens prüfen:
- §13a Single Source of Truth (TrainingModelView nutzt @Query, keine Snapshot-Kopie) ✓
- §13h (kein neuer @State VM-Snapshot) ✓
- §14 Predicate Anti-Patterns (nur `id == UUID` und `workoutId == UUID`) ✓
- AppStyle (alle benutzten Tokens vorhanden) ✓
- adr-required.sh Hook: ADR-0001/2/3 sind als Verweise im Commit-Body ✓

### 8. Manueller Edit-Block-Check (ADR-0003)

Auf Simulator: Während aktiver Session Edit-Button auf Exercise X anklicken — sollte disabled sein oder Hinweis zeigen.

## Definition of Done

- [ ] `TrainingModelView.swift` existiert, dispatched in NavigationDestination
- [ ] `MuscleCategorySelectionModelView.swift` existiert, ersetzt alte Selection-View
- [ ] Beide T2-Tests sind GRÜN
- [ ] Manueller Test auf Simulator bestätigt beide Bug-Fixes
- [ ] Full Test Suite grün
- [ ] Edit-Block während Session funktioniert (ADR-0003)
- [ ] Reviewing-code-changes Skill durchlaufen, Stamp geschrieben
- [ ] adr-required.sh Hook lässt durch (ADR-Verweise im Commit-Body)
- [ ] Commit-Message: "T7: integrate TrainingModelView + MuscleCategorySelectionModelView (fixes Bug 1 + Bug 2)"

## Akzeptanzkriterien

- Bug 1 und Bug 2 aus dem ursprünglichen User-Report sind behoben
- Beide automatisierten Tests beweisen es
- Architekturschicht ist klar: SwiftData-Code lebt nur in FitnessPersistenceUI
- Edit-Race ist via ADR-0003 ausgeschlossen
