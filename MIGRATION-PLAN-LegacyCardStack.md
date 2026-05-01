# Migration: Legacy Card Stack → Model Card Stack

**Status:** Geplant — vor Migration zuerst aktuelle Style-Tweaks committen.
**Scope:** Lösche Legacy-Stack (Snapshot-VM-basierte Cards), nutze überall die `*ModelView`-Variante (`@Bindable ExerciseModel`).
**Begründung:** Style-Tweaks müssen aktuell in zwei Dateien synchronisiert werden (`IdleActiveCardView` + `IdleActiveCardModelView`). Das ist Code-Duplikation mit hohem Pflegeschmerz und blockiert die ADR-0001 Migration.

---

## Aktuelle Architektur (Doppel-Stack)

| Legacy (zu löschen)             | Model (Ziel-Zustand)              | Datenquelle                       |
|---------------------------------|-----------------------------------|-----------------------------------|
| `ExerciseCardContainerView`     | `ExerciseCardModelView`           | `ExerciseCardViewModel` Snapshot  |
| `IdleActiveCardView`            | `IdleActiveCardModelView`         | → `@Bindable ExerciseModel`       |
| `ActiveCardView`                | `ActiveCardModelView`             |                                   |
| `InactiveCardView`              | `InactiveCardModelView`           |                                   |
| `ExerciseCardViewModel`         | (entfällt)                        |                                   |

**Hauptunterschied:** Legacy-Stack nutzt einen `Exercise`-Snapshot der via `ExerciseCardViewModel` aus `ExerciseManagementService` synchronisiert werden muss. Model-Stack bindet direkt an SwiftData `@Model`, SwiftUI tracked Änderungen automatisch — kein Sync, kein Polling, keine Stale-State-Bugs.

**Architektur-Referenz:** ADR-0001 (`@Model` als Single Source of Truth), siehe Kommentar in `ExerciseCardModelView.swift`.

---

## Ist-Zustand: Wer ruft den Legacy-Stack auf?

**Einziger aktiver Aufrufer des Legacy-Stacks:**

```
FitnessApp/Features/Training/TrainingView.swift
└── ExerciseCardContainerView(viewModel: cardViewModel, ...)
    └── IdleActiveCardView / ActiveCardView / InactiveCardView
        └── ExerciseCardViewModel
```

**Andere Stellen** (`MuscleCategoryView`, `MuscleCategorySelectionView`) nutzen bereits den Model-Stack über `ExerciseCardModelView`. Die Migration betrifft also **nur einen einzigen View** — `TrainingView`.

---

## Migrations-Schritte

### Schritt 0: Vor-Validierung (vor jedem Commit)

```bash
cd Packages/FitnessExercise && xcodebuild test -scheme FitnessExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -skipMacroValidation
```

Erwartung: 90/90 Tests passen.

---

### Schritt 1: `NavigationDestination.training` auf `ExerciseModel` umstellen

**Datei:** `Packages/FitnessExercise/Sources/FitnessExercise/NavigationDestination.swift`

```swift
// BEFORE
case training(Exercise, MuscleCategoryGroup)

// AFTER
case training(ExerciseModel, MuscleCategoryGroup)
```

**Aber Achtung:** `ExerciseModel` ist `@_spi(PersistenceUI) public` — nicht direkt sichtbar in `FitnessExercise`. Lösungen:

- **Option A (empfohlen):** Navigation hält weiterhin die `id: UUID`, `TrainingView` löst sie selbst zu `ExerciseModel` via `@Query` auf.

  ```swift
  case training(exerciseId: UUID, category: MuscleCategoryGroup)
  ```

  Das hat 3 Vorteile:
  1. Keine SPI-Leakage in `NavigationDestination`
  2. `@Query` rendert immer die aktuelle Version (auch nach Edits)
  3. Deep-Links / State-Restore brauchen nur eine UUID

- **Option B:** `FitnessExercise` deklariert `@_spi(PersistenceUI) import FitnessPersistenceUI`. Verstößt gegen Layering, weil `NavigationDestination` Domain-nahe ist.

→ **Plan: Option A.**

---

### Schritt 2: Aufrufer von `.training(...)` aktualisieren

Suche nach allen `router.navigate(to: .training(...))` und `case .training(...)`:

| Datei                                                                          | Aktion                                                                                                                                                       |
|--------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategoryView.swift`    | `.training(selectedExercise, group)` → `.training(exerciseId: selectedExercise.id, category: group)`                                                         |
| `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategorySelectionView.swift` | gleiche Anpassung                                                                                                                                            |
| `FitnessApp/Shared/Navigation/UITestLaunchStrategy.swift`                      | `.training(exercise, category)` → `.training(exerciseId: exercise.id, category: category)`                                                                   |
| `FitnessApp/FitnessAppApp.swift`                                               | `case .training(let exercise, let category)` → `case .training(let exerciseId, let category)`, `TrainingView(exerciseId: exerciseId, category: category)` |
| `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategoryView.swift:306` | `if let exercise = trainingCoordinator.currentExercise ?? nextDomain { router.navigate(to: .training(exercise, group)) }` → nur `exercise.id` reichen        |

---

### Schritt 3: `TrainingView` umstellen

**Datei:** `FitnessApp/Features/Training/TrainingView.swift`

#### 3.1 Init umstellen

```swift
// BEFORE
struct TrainingView: View {
    let exercise: Exercise
    let category: MuscleCategoryGroup
    @State private var cardViewModel: ExerciseCardViewModel
    
    init(exercise: Exercise, category: MuscleCategoryGroup) {
        self.exercise = exercise
        ...
        self._cardViewModel = State(wrappedValue: ExerciseCardViewModel(exercise: exercise) { ... })
    }
}

// AFTER
@_spi(PersistenceUI) import FitnessPersistenceUI
@_spi(PersistenceUI) import FitnessStorage

struct TrainingView: View {
    let exerciseId: UUID
    let category: MuscleCategoryGroup
    
    @Query private var models: [ExerciseModel]
    
    init(exerciseId: UUID, category: MuscleCategoryGroup) {
        self.exerciseId = exerciseId
        self.category = category
        self._models = Query(filter: #Predicate<ExerciseModel> { $0.id == exerciseId })
        ...
    }
}
```

#### 3.2 Body — `ExerciseCardContainerView` → `ExerciseCardModelView`

```swift
// BEFORE
ExerciseCardContainerView(
    viewModel: cardViewModel,
    onEdit: { ... },
    ...
)

// AFTER
if let model = models.first {
    ExerciseCardModelView(
        model: model,
        onEdit: { ... },
        ...
    )
}
```

#### 3.3 Aufrufe von `cardViewModel.exercise` ersetzen

Im `body`/Coordinator-Aufrufen alle `cardViewModel.exercise` und `exercise` (das gespeicherte Property) durch `model.toDomain()` ersetzen — soweit Coordinator-APIs `Exercise` erwarten. Idealerweise akzeptieren die APIs irgendwann auch `ExerciseModel`.

Konkret:
- `trainingCoordinator.startTraining(for: exercise)` → `trainingCoordinator.startTraining(for: model.toDomain())`
- `TrainingActionBarComponent(exercises: [exercise], ...)` → `[model.toDomain()]`

#### 3.4 `#Preview` anpassen

Preview braucht ein `ExerciseModel` — gestützt auf `PreviewModelContainer` aus `FitnessPersistenceUI`-Tests/Sample-Container.

---

### Schritt 4: Tests anpassen

**`Packages/FitnessExercise/Tests/FitnessExerciseTests/ExerciseCardViewModelTests.swift`**

Die Datei testet `ExerciseCardViewModel`. Wenn der ViewModel komplett gelöscht wird, muss die Datei auch gelöscht werden. Vorher prüfen ob die getesteten Verhalten in den `*ModelView`-Tests bereits abgedeckt sind:

- `Packages/FitnessPersistenceUI/Tests/FitnessPersistenceUITests/ExerciseCardModelViewTests.swift`
- `Packages/FitnessPersistenceUI/Tests/FitnessPersistenceUITests/CategoryTileModelViewTests.swift`

Falls Lücken: Tests in `ExerciseCardModelViewTests` ergänzen.

---

### Schritt 5: Legacy-Dateien löschen

In dieser Reihenfolge (jeder Schritt: build + test):

1. `Packages/FitnessExercise/Sources/FitnessExercise/ExerciseCardContainerView.swift`
2. `Packages/FitnessExercise/Sources/FitnessExercise/IdleActiveCardView.swift`
3. `Packages/FitnessExercise/Sources/FitnessExercise/ActiveCardView.swift`
4. `Packages/FitnessExercise/Sources/FitnessExercise/InactiveCardView.swift`
5. `Packages/FitnessExercise/Sources/FitnessExercise/ExerciseCardViewModel.swift`
6. `Packages/FitnessExercise/Tests/FitnessExerciseTests/ExerciseCardViewModelTests.swift`

**Nach jedem Löschen:** `xcodebuild test` der betroffenen Pakete laufen lassen.

---

### Schritt 6: Aufräumen

- Kommentar in `Packages/FitnessTraining/Sources/FitnessTraining/Feedback/FeedbackSheetComponent.swift:8` — entfernt `IdleActiveCardView` aus dem Doc-Comment, da nicht mehr existent.
- Kommentar in `Packages/FitnessPersistenceUI/Sources/FitnessPersistenceUI/IdleActiveCardModelView.swift:17–22` — entfernen oder umformulieren (nicht mehr "spiegel von IdleActiveCardView").
- Kommentar in `Packages/FitnessPersistenceUI/Sources/FitnessPersistenceUI/ExerciseCardModelView.swift:16–17` — `(in T7-0 aus FitnessExercise.ExerciseCardContainerView nach FitnessCore gehoben)` aktualisieren.
- `architecture-documentation.md` aktualisieren (Feature Map: Legacy-Card-Stack entfernen, Model-Stack als kanonisch markieren).
- ADR-0001 Status auf "Migration abgeschlossen — T8d done" setzen falls noch nicht geschehen.

---

### Schritt 7: Architektur-Validierung

Nach kompletter Migration muss in der Idle View der Style-Code **nur in einer Datei** existieren:

```bash
rg -n 'colorMultiply.*greenLight' Packages/
```

Erwartung: Nur noch ein Treffer in `IdleActiveCardModelView.swift` (plus `PainRegionGrid.swift`).

---

## Risiken

| Risiko                                                                 | Mitigation                                                                                                                          |
|------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| `@Query`-basierte Resolution in `TrainingView` rendert leeren View, wenn das Model noch nicht da ist | `if let model = models.first { ExerciseCardModelView(...) } else { ProgressView() }` oder Loading-Placeholder                       |
| `TrainingCoordinator.startTraining(for: Exercise)` braucht weiterhin `Exercise` | `model.toDomain()` ist trivial — bleibt erhalten als Brücke                                                                          |
| UI-Tests (`UITestLaunchStrategy`) brechen                              | UUID-basierte Navigation funktioniert dort genauso, da `TestExerciseFixture` schon eine ID hat                                       |
| `ExerciseCardViewModel` wird woanders genutzt (außer in den 4 Card-Views) | Vor Löschen: `rg ExerciseCardViewModel Packages/ FitnessApp/` — aktuell nur Card-Stack + Tests                                       |
| Pre-existing `@Query` mit dynamischem Filter ohne `.id()` (siehe SKILL §14d) | TrainingView ist eine einzelne Instanz pro Navigation — `.id(exerciseId)` am `NavigationStack`-Destination als Safety-Net           |

---

## Erfolgs-Kriterien

- [ ] `TrainingView` nutzt `ExerciseCardModelView` statt `ExerciseCardContainerView`
- [ ] `NavigationDestination.training` nimmt `UUID` statt `Exercise`
- [ ] Alle Legacy-Dateien (4 Views + 1 ViewModel + 1 Test) gelöscht
- [ ] `rg IdleActiveCardView Packages/` liefert keine Treffer mehr (nur `IdleActiveCardModelView`)
- [ ] FitnessExercise + FitnessPersistenceUI Tests grün
- [ ] FitnessAppUITests grün (Training-Flow)
- [ ] Style-Code für Idle-Icon existiert nur einmal — in `IdleActiveCardModelView.swift`
- [ ] `architecture-documentation.md` aktualisiert

---

## Aufwand-Schätzung

- Vorbereitung & Aufrufer-Updates (Schritt 1–2): ~30 Min
- TrainingView Umstellung (Schritt 3): ~45 Min
- Tests (Schritt 4): ~30 Min
- Cleanup (Schritt 5–7): ~30 Min
- **Gesamt:** 2–3 Stunden inkl. Testlauf

---

## Quick-Win Alternative (falls Migration zurückgestellt werden muss)

Wenn die Migration auf später verschoben wird, kann der **Pflegeschmerz** trotzdem reduziert werden, indem ein gemeinsamer Style-Modifier extrahiert wird:

```swift
// Packages/FitnessUI/Sources/FitnessUI/IdleCategoryIconStyle.swift
public extension View {
    func idleCategoryIconStyle() -> some View {
        self
            .saturation(0.6)
            .brightness(0.03)
            .colorMultiply(AppStyle.Color.greenLight)
    }
}
```

Beide `IdleActiveCardView`s nutzen `.idleCategoryIconStyle()`, Tweaks passieren nur einmal. ~5 Min Arbeit, blockiert die spätere Migration nicht.
