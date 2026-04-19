# T5 — Pilot: ExerciseCardModelView (+ 3 Variant-Views) in FitnessPersistenceUI

> **Layer**: Pilot-Migration
> **Vorbedingung**: T4 (Package)
> **Blockiert**: T7 (TrainingView)
> **Aufwand**: ~120 min
> **Architektur-Variante**: **E** (echter Refactor — Card-Files in FitnessPersistenceUI parallel neu anlegen)

## Ziel

Eine neue View-Familie in `FitnessPersistenceUI` die direkt `@Bindable ExerciseModel` konsumiert statt `Exercise`-struct + `ExerciseCardViewModel`-Snapshot. Macht den ersten Bug-1-Test (`cardVariantUpdatesAfterFinish`) grün — sobald T7 die View einsetzt.

## Architektur-Begründung (warum E, nicht A/B/C/D)

**Empirischer Befund aus dem Recon**: Die existierenden Cards (`ActiveCardView`, `IdleActiveCardView`, `InactiveCardView`) lesen `viewModel.exercise.X` durch das ganze Layout, ziehen Analytics-Daten aus `analyticsViewModel.weightPhases(for:)`, `loadAnalytics(for:)`, `lastTrainingDate(for:)`, beobachten `analyticsViewModel.changeCount` und besitzen interne Sheet-States. Sie sind nicht trivial.

**Verworfene Alternativen**:

- **A (Bridge)**: `ExerciseCardModelView` baut pro `body`-recompute einen `ExerciseCardViewModel` und reicht ihn an die alten Cards. Verletzt ADR-0001 (re-introduces snapshot), kaputt durch State-Reset bei jedem Recompute.
- **B (Layout-Kopie ohne Card-Verschiebung)**: Würde die Card-Layouts in der neuen View neu bauen. Code-Duplikation, aber: erzeugt während T6/T7 zwei parallele Card-Familien, jede UI-Änderung muss zweimal gemacht werden.
- **C1c (Plain-Param-Boundary)**: Würde Analytics-Daten als Plain-Param in die neue View reichen. Beim Recon zerbrochen — Analytics-Einbettung ist zu tief (Phasen, sheets, changeCount).

**E (gewählt)**: Card-Files **parallel** in `FitnessPersistenceUI` neu anlegen, Datenquelle auf `@Bindable model: ExerciseModel` umstellen. Alte Card-Files in `FitnessExercise` bleiben für `ExerciseCardContainerView` stehen. T7 schaltet Aufruf um, T8 löscht alte Cards + `ExerciseCardViewModel` + `cardViewModels`-Caches.

**Warum kein Verschieben statt Kopieren**: Aufrufer in `MuscleCategoryViewModel` und `MuscleCategorySelectionViewModel` halten heute `cardViewModels: [UUID: ExerciseCardViewModel]`-Caches und reichen diese in `ExerciseCardContainerView`. Würden wir die Cards verschieben, müssten T7 + Aufrufer mitziehen — das macht T5 zu viel größer und verletzt die Plan-Sequenz (T5 = Pilot isoliert, T7 = Switch, T8 = Cleanup).

**Bewusst aufgeschobener Cleanup**: `analyticsViewModel.changeCount`-Pattern (Counter-as-Reactivity-Surrogat) bleibt in den neuen Cards vorerst übernommen. ADR-0001 markiert das als Anti-Pattern für Löschung in T8 — nicht in T5.

## Kontext

Heutige Card-Familie in `Packages/FitnessExercise/Sources/FitnessExercise/`:

- `ExerciseCardContainerView.swift` — Variant-Resolver + Switch (`CardVariant.completed/.active/.idle`)
- `ActiveCardView.swift` — laufende Übung
- `IdleActiveCardView.swift` — bereit zum Start (mit Play-Button)
- `InactiveCardView.swift` — abgeschlossen (Checkmark)

Alle drei nehmen `viewModel: ExerciseCardViewModel` (Snapshot-Reference, Bug-1-Quelle).

`CardVariant` und `ExerciseCardContainerView.resolveVariant(...)` sind **bereits `public`** — werden aus dem neuen Container aufgerufen, kein Verschieben nötig.

## Schritte

### 1. Package-Dependencies erweitern

`Packages/FitnessPersistenceUI/Package.swift`:

- Zusätzlich: `.package(path: "../FitnessAnalytics")`, `.package(path: "../FitnessExercise")`
- Target-Dependencies: `"FitnessAnalytics"`, `"FitnessExercise"` ergänzen

`FitnessExercise` wird gebraucht für `CardVariant`, `ExerciseCardContainerView.resolveVariant`, `ExerciseEditMode`, `MuscleCategoryIDs`, `ExerciseIDs`, `ExerciseCardIDs`, `WeightPhaseTileView`, `SetTileView`, `WeightFormatter` (aus FitnessUI), `CardBackground` (aus FitnessUI), `MetricChipView` (aus FitnessUI).

Cycle-Check: `FitnessExercise` darf NICHT zurück auf `FitnessPersistenceUI` zeigen (heute nicht der Fall — bestätigt).

### 2. ExerciseCardModelView (Container)

`Packages/FitnessPersistenceUI/Sources/FitnessPersistenceUI/ExerciseCardModelView.swift`

Hat im Wesentlichen die gleiche Signatur wie `ExerciseCardContainerView`, ersetzt `viewModel: ExerciseCardViewModel` durch `@Bindable model: ExerciseModel`. Variant-Resolver wird live über `model.isCompleted` aufgerufen — das ist der Schlüssel-Fix für Bug 1.

```swift
import SwiftUI
import SwiftData
import FitnessCore
import FitnessExercise
import FitnessAnalytics
@_spi(PersistenceUI) import FitnessStorage

public struct ExerciseCardModelView: View {
    @Bindable public var model: ExerciseModel
    public let onEdit: (Exercise, ExerciseEditMode) -> Void
    public let isEditable: Bool
    public var analyticsViewModel: AnalyticsViewModel
    public var activeSetViewModel: ActiveSetViewModel
    public let onStart: ((Exercise) -> Void)?
    public let onReset: ((Exercise) -> Void)?
    public let isActiveSetVisible: Bool
    public let isResetEnabled: Bool
    public let isInProgress: Bool

    public init(
        model: ExerciseModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        analyticsViewModel: AnalyticsViewModel,
        activeSetViewModel: ActiveSetViewModel,
        onStart: ((Exercise) -> Void)?,
        onReset: ((Exercise) -> Void)?,
        isActiveSetVisible: Bool,
        isResetEnabled: Bool,
        isInProgress: Bool = false
    ) {
        self.model = model
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.analyticsViewModel = analyticsViewModel
        self.activeSetViewModel = activeSetViewModel
        self.onStart = onStart
        self.onReset = onReset
        self.isActiveSetVisible = isActiveSetVisible
        self.isResetEnabled = isResetEnabled
        self.isInProgress = isInProgress
    }

    public var body: some View {
        // Live-read: jedes mal wenn model.isCompleted via @Bindable mutiert,
        // recomputed body und der Variant-Switch nimmt den neuen Pfad.
        let variant = ExerciseCardContainerView.resolveVariant(
            isCompleted: model.isCompleted,
            isActiveSetVisible: isActiveSetVisible,
            activeExerciseId: activeSetViewModel.currentExercise?.id,
            exerciseId: model.id
        )

        switch variant {
        case .completed:
            InactiveCardModelView(
                model: model,
                onEdit: onEdit,
                isEditable: isEditable,
                analyticsViewModel: analyticsViewModel,
                onReset: onReset,
                isResetEnabled: isResetEnabled
            )
            .accessibilityIdentifier(ExerciseCardIDs.completedCard(model.id))
        case .active:
            ActiveCardModelView(
                model: model,
                onEdit: onEdit,
                isEditable: isEditable,
                analyticsViewModel: analyticsViewModel
            )
            .accessibilityIdentifier(ExerciseCardIDs.activeCard(model.id))
        case .idle:
            IdleActiveCardModelView(
                model: model,
                analyticsViewModel: analyticsViewModel,
                onEdit: onEdit,
                isEditable: isEditable,
                onStart: onStart,
                isInProgress: isInProgress
            )
            .accessibilityIdentifier(ExerciseCardIDs.idleCard(model.id))
        }
    }
}
```

### 3. ActiveCardModelView, IdleActiveCardModelView, InactiveCardModelView

Layout 1:1 aus den existierenden Cards übernehmen, drei mechanische Substitutionen:

- `viewModel: ExerciseCardViewModel` → `@Bindable var model: ExerciseModel`
- `viewModel.exercise.X` → `model.X` (live-read über `@Bindable`)
- `onEdit(viewModel.exercise, .seat)` → `onEdit(model.toDomain(), .seat)` (Boundary zur Aufrufer-API; T8 stellt evtl. später auf `(ExerciseModel, ...)` um)
- `onStart(viewModel.exercise)` → `onStart(model.toDomain())`
- `onReset(viewModel.exercise)` → `onReset(model.toDomain())`

`@State`-Felder für Sheets/Expand/Caches bleiben unverändert. Analytics-Aufrufe (`analyticsViewModel.weightPhases(for: model.id)` etc.) bleiben unverändert.

**`changeCount`-Pattern**: bleibt vorerst übernommen (`.onChange(of: analyticsViewModel.changeCount) { ... }`) — ADR-0001 markiert als Cleanup-Ziel in T8.

### 4. CardVariant-Resolver

Bleibt wo er ist (`ExerciseCardContainerView.resolveVariant` in `FitnessExercise`, schon `public`). Wird vom neuen Container aufgerufen.

### 5. Tests

`Packages/FitnessPersistenceUI/Tests/FitnessPersistenceUITests/ExerciseCardModelViewTests.swift`

Zwei Test-Klassen:

**A. `ResolveVariantTests`** — pure Funktionstests, kein Container nötig:

- `.completed` wenn `isCompleted == true` (egal ob aktiv)
- `.active` wenn `isCompleted == false`, `isActiveSetVisible == true`, `activeExerciseId == exerciseId`
- `.idle` wenn `isCompleted == false`, kein Active-Match

**B. `Bug1SanityTests`** — beweist dass `model.isCompleted` Mutation den Variant-Switch tatsächlich umlenkt:

- In-Memory `ModelContainer` über `WorkoutModel.self, ExerciseModel.self`
- `ExerciseModel` mit `isCompleted: false` einfügen, `try ctx.save()`
- `resolveVariant(isCompleted: model.isCompleted, ...)` → `.idle`
- `model.isCompleted = true; try ctx.save()`
- `resolveVariant(isCompleted: model.isCompleted, ...)` → `.completed`

(Der echte UI-Render-Beweis kommt aus dem Bug-1-Invariant-Test in T2 — sobald T7 die View einsetzt, wird der grün.)

```swift
import Foundation
import SwiftData
import Testing
import FitnessCore
import FitnessExercise
@_spi(PersistenceUI) import FitnessStorage
@testable import FitnessPersistenceUI

@MainActor
@Suite("ExerciseCardModelView — variant resolution")
struct ResolveVariantTests {

    @Test("Completed model → .completed, regardless of active state")
    func completedDominates() {
        let id = UUID()
        let v = ExerciseCardContainerView.resolveVariant(
            isCompleted: true,
            isActiveSetVisible: true,
            activeExerciseId: id,
            exerciseId: id
        )
        #expect(v == .completed)
    }

    @Test("Active set visible AND id matches → .active")
    func activeWhenMatched() {
        let id = UUID()
        let v = ExerciseCardContainerView.resolveVariant(
            isCompleted: false,
            isActiveSetVisible: true,
            activeExerciseId: id,
            exerciseId: id
        )
        #expect(v == .active)
    }

    @Test("Active set visible but different id → .idle")
    func idleWhenIdMismatch() {
        let v = ExerciseCardContainerView.resolveVariant(
            isCompleted: false,
            isActiveSetVisible: true,
            activeExerciseId: UUID(),
            exerciseId: UUID()
        )
        #expect(v == .idle)
    }
}

@MainActor
@Suite("ExerciseCardModelView — Bug-1 sanity (live model.isCompleted)")
struct Bug1SanityTests {

    @Test("Variant flips from .idle to .completed when model.isCompleted mutates")
    func variantFlipsOnMutation() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutModel.self, ExerciseModel.self,
            configurations: config
        )
        let ctx = ModelContext(container)

        let workoutId = UUID()
        let workout = WorkoutModel(
            id: workoutId,
            name: "W",
            selectedCategories: [MuscleCategoryGroup.chest.rawValue],
            createdDate: .now,
            lastModified: .now
        )
        ctx.insert(workout)

        let model = ExerciseModel(
            id: UUID(),
            workoutId: workoutId,
            name: "Bench",
            weight: 60,
            reps: 10,
            sets: 3,
            iconName: MuscleCategoryGroup.chest.defaultIconName,
            category: MuscleCategoryGroup.chest.rawValue,
            workout: workout
        )
        ctx.insert(model)
        try ctx.save()

        let initial = ExerciseCardContainerView.resolveVariant(
            isCompleted: model.isCompleted,
            isActiveSetVisible: false,
            activeExerciseId: nil,
            exerciseId: model.id
        )
        #expect(initial == .idle)

        model.isCompleted = true
        try ctx.save()

        let after = ExerciseCardContainerView.resolveVariant(
            isCompleted: model.isCompleted,
            isActiveSetVisible: false,
            activeExerciseId: nil,
            exerciseId: model.id
        )
        #expect(after == .completed)
    }
}
```

### 6. Build + Tests

```bash
cd ~/Documents/repo/FitnessApp/Packages/FitnessPersistenceUI && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild test -scheme FitnessPersistenceUI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipMacroValidation 2>&1 | tail -30
```

Plus voller App-Build:

```bash
cd ~/Documents/repo/FitnessApp && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
xcodebuild build -scheme FitnessApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tail -30
```

### 7. Architecture-Doc + Stamps

- `architecture-documentation.md`: `FitnessPersistenceUI`-Eintrag erweitern um die 4 neuen Files + Hinweis "alte Cards in `FitnessExercise` bleiben bis T8"
- `code-changes.stamp.md` schreiben
- `test-execution.stamp.md` schreiben

### 8. Reviewing-code-changes Skill anwenden

- §13b Reactive over Polling — `@Bindable` direkt, kein Counter-Polling im neuen Container ✓
- §13h Duplicate Domain-State Holders — neue View hält keinen `@State`-VM-Snapshot ✓
- §14 SwiftData Predicate Anti-Patterns — keine `#Predicate` ✓
- AppStyle-Konventionen — alle benutzten AppStyle-Tokens 1:1 aus alten Cards übernommen
- Architektur-Sync — `FitnessPersistenceUI` bekommt 4 neue Files, in arch-doc dokumentiert

## Definition of Done

- [ ] `Package.swift` um `FitnessAnalytics` + `FitnessExercise` erweitert
- [ ] 4 neue Files in `FitnessPersistenceUI/Sources/FitnessPersistenceUI/` (Container + 3 Variants)
- [ ] `ResolveVariantTests` (3) + `Bug1SanityTests` (1) grün
- [ ] Existierende Cards in `FitnessExercise` bleiben unverändert (parallel) — werden in T7 (Switch) + T8 (Löschen) verarbeitet
- [ ] Voller App-Build grün, alle anderen Package-Tests bleiben grün
- [ ] arch-doc aktualisiert, Stamps geschrieben
- [ ] Commit-Message: `T5: pilot ExerciseCardModelView (+ 3 variants) in FitnessPersistenceUI per ADR-0001`

## Akzeptanzkriterien

`ExerciseCardModelView` ist verfügbar und nutzt `@Bindable ExerciseModel` als einzige Datenquelle für Bug-1-relevantes State (`isCompleted`). Sie wird in T7 die snapshot-basierte `ExerciseCardContainerView` im Routing ersetzen.

## Aufgeschoben (T8)

- `analyticsViewModel.changeCount`-Polling-Pattern in den 3 Variant-Views (heute übernommen aus den alten Cards) — wird durch sauberes `@Observable`-Tracking ersetzt
- Edit-Callback-Signatur `(Exercise, ExerciseEditMode) -> Void` (heute via `model.toDomain()` an Boundary) — kann auf `(ExerciseModel, ExerciseEditMode) -> Void` umgestellt werden sobald alle Aufrufer migriert sind
- `cardViewModels: [UUID: ExerciseCardViewModel]`-Caches in `MuscleCategoryViewModel` + `MuscleCategorySelectionViewModel`
- `ExerciseCardViewModel` selbst, `syncExercise(...)`-Methode
- 4 alte Card-Files in `FitnessExercise`
