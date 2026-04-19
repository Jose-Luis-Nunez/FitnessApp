# T7 — Inkrementelle UI-Migration (Bug 1 + Bug 2 live behoben)

> **Layer**: Pilot-Migration (Integration in echte App-Routen)
> **Vorbedingung**: T5 (Cards), T6 (Tile)
> **Blockiert**: T8 (Cleanup)
> **Aufwand**: ~150 min, **3 atomare Commits** (T7-0, T7a, T7b)

## Senior-Empfehlung — Big-Bang verworfen

Der ursprüngliche Plan-Skeleton schlug eine Big-Bang-Migration vor: zwei
komplett neue Top-Level-Views (`TrainingModelView`, `MuscleCategorySelectionModelView`)
in `FitnessPersistenceUI`, die `TrainingView` (210 LOC, mit
TrainingSessionComponent / ActionBar / FeedbackSheet / Cancel-Flow / Auto-Pop)
und `MuscleCategorySelectionView` (506 LOC, mit WorkoutDropdown / Filter-Bar /
Picker-Sheets / Mini-Menu / Scroll-Tracking) ersetzen. Das bedeutet:

- ~700 LOC View-Logik dupliziert oder ins falsche Package verschoben.
- Auto-Pop-Logik bei Session-Ende, Cancel-Flow, Picker-Sheets, Mini-Menu —
  alles muss neu geschrieben werden ohne dass es Bug 1 / Bug 2 hilft.
- Kein atomarer Rollback möglich.

**Ehrliche Bug-Lokalisierung** (Senior-Recon):

- **Bug 1** (Card flippt nicht auf "completed" nach `finishExercise`): wird
  sichtbar in `MuscleCategoryView.exerciseListSection` *nach* dem `router.pop()`
  aus `TrainingView`. Die Card oben in `TrainingView` ist Edge-Case (View
  poppt direkt automatisch).
- **Bug 2** (Tile-Count "X of Y" aktualisiert nicht): sichtbar in
  `MuscleCategorySelectionView.categoryList`.

→ Die echten Aufrufer-Stellen sind **drei Code-Sites in zwei Views** in
`FitnessExercise` — nicht zwei komplette neue Top-Level-Views.

## Architektur-Hürde: Dependency Cycle

`FitnessPersistenceUI` hängt heute (T5) von `FitnessExercise` ab — wegen:

1. `ExerciseCardContainerView.resolveVariant(...)` (statische Funktion,
   wiederverwendet vom neuen `ExerciseCardModelView`)
2. `CardVariant` enum (returntyp)
3. `CategoryTileViewConstants` (CGFloat-Konstanten, vom neuen `CategoryTileModelView`)
4. `InactiveCardView.ResetButton.Constants.size` (eine `CGFloat`-Konstante,
   vom neuen `InactiveCardModelView`)

`FitnessExercise → FitnessPersistenceUI` (was T7a/T7b bräuchten) wäre
zirkulär. Bevor wir die echten Aufrufer migrieren können, muss der Cycle
aufgelöst werden — sauber, einmal, dokumentiert.

## Plan: 3 Phasen, 3 Commits

| Phase | Inhalt | Aufwand | Commit |
|-------|--------|---------|--------|
| **T7-0** | Cycle-Auflösung: `CardVariant` + `resolveCardVariant` nach `FitnessCore`; `CategoryTileViewConstants` + `ExerciseCardLayout.resetButtonSize` nach `FitnessUI`. `FitnessPersistenceUI` Dependency auf `FitnessExercise` entfernen. | ~30 min | "T7-0: break FitnessPersistenceUI → FitnessExercise cycle" |
| **T7a** | `CategoryTileView` durch `CategoryTileModelView` in `MuscleCategorySelectionView.categoryList` ersetzen. **Live Bug 2 fix.** `FitnessExercise` darf jetzt `@_spi(PersistenceUI) import FitnessPersistenceUI`. | ~45 min | "T7a: live-fix Bug 2 by routing CategoryTileModelView through MuscleCategorySelectionView" |
| **T7b** | `ExerciseCardContainerView` durch `ExerciseCardModelView` in `MuscleCategoryView.exerciseListSection` ersetzen. **Live Bug 1 fix.** | ~75 min | "T7b: live-fix Bug 1 by routing ExerciseCardModelView through MuscleCategoryView" |

Bewusst **deferred** (kosmetisch oder Edge-Case, T8 oder später):
- `MuscleCategorySelectionView.allExercisesList` (List-Mode) — selber
  Anti-Pattern wie `MuscleCategoryView`, aber selten genutzt.
- `TrainingView` Card oben — View poppt automatisch, Card ist <500ms sichtbar.

## T7-0 — Cycle-Auflösung (Vorbereitung)

### Was verschoben wird

**Nach `Packages/FitnessCore/Sources/FitnessCore/CardVariant.swift` (neu)**:

```swift
public enum CardVariant: Equatable, Sendable {
    case completed
    case active
    case idle
}

public func resolveCardVariant(
    isCompleted: Bool,
    isActiveSetVisible: Bool,
    activeExerciseId: UUID?,
    exerciseId: UUID
) -> CardVariant {
    if isCompleted { return .completed }
    if isActiveSetVisible, activeExerciseId == exerciseId { return .active }
    return .idle
}
```

`FitnessCore` hat keine SwiftUI-Dependency — `CardVariant` ist ein
Domain-Konzept (Card-Status), kein UI-Pixel. Sauberer Ort.

**In `Packages/FitnessExercise/.../ExerciseCardContainerView.swift`**:

- Lokales `enum CardVariant` löschen.
- `static func resolveVariant(...)` löschen oder als
  `@available(*, deprecated, message: "Use FitnessCore.resolveCardVariant")`
  Wrapper belassen.
- `body` ruft `resolveCardVariant(...)` direkt.

**Nach `Packages/FitnessUI/Sources/FitnessUI/ExerciseCardLayout.swift` (neu)**:

```swift
import SwiftUI

public enum ExerciseCardLayout {
    public enum CategoryTile {
        public static let contentPadding: CGFloat = AppStyle.Padding.screenHorizontal
        public static let verticalSpacing: CGFloat = 12
        public static let iconSize: CGFloat = 80
    }

    public enum ProgressBar {
        public static let height: CGFloat = 9
    }

    public enum ResetButton {
        public static let size: CGFloat = 40
        public static let iconSize: CGFloat = 32
    }
}
```

**In `Packages/FitnessExercise/.../CategoryTileView.swift`**:
- `CategoryTileViewConstants.CategoryTile.contentPadding` →
  `ExerciseCardLayout.CategoryTile.contentPadding` (gleich für die anderen)
- Lokales `CategoryTileViewConstants` enum löschen oder als typealias zu
  `ExerciseCardLayout` belassen für T8.

**In `Packages/FitnessExercise/.../InactiveCardView.swift`**:
- `ResetButton.Constants.size` weiter benutzen (lokal in der View) — die Konstante
  in `ExerciseCardLayout` ist nur für `FitnessPersistenceUI`. Aber: **derselbe
  Wert** (`40`) — duplikation in T8 zusammen mit Card-Deletion auflösen.
  Alternative: lokale Konstante als `= ExerciseCardLayout.ResetButton.size` setzen,
  damit klar ist dass es eine Quelle gibt.

**In `Packages/FitnessPersistenceUI/...`**:
- Alle 4 ModelView-Files: `import FitnessExercise` ersetzen mit den neuen
  Quellen (`FitnessCore` für `CardVariant`/`resolveCardVariant`,
  `FitnessUI.ExerciseCardLayout` für Konstanten).
- `Package.swift`: `.product(name: "FitnessExercise", ...)` entfernen.
- Tests: `import FitnessExercise` entfernen, neue Importe.

### T7-0 Build-Verifikation

```bash
# Aus Packages/FitnessPersistenceUI:
xcodebuild build -scheme FitnessPersistenceUI -destination ... -skipMacroValidation

# Tests:
xcodebuild test  -scheme FitnessPersistenceUI -destination ... -skipMacroValidation

# Aus Repo-Root:
xcodebuild build -scheme FitnessApp -destination ...

# Alle Packages parallel:
/tmp/test-all.sh
```

Erwartet: 543/543 grün, kein Cycle.

### T7-0 Commit

`T7-0: break FitnessPersistenceUI → FitnessExercise cycle by hoisting CardVariant + layout constants`

Body listet die 4 verschobenen Symbole und nennt T7a/T7b als Folge.

---

## T7a — Tile-Migration (Bug 2 live fix)

### Reihenfolge der Änderungen

1. **`Packages/FitnessExercise/Package.swift`**: Dependency auf
   `FitnessPersistenceUI` (Workspace-internes Package) hinzufügen.
2. **`Packages/FitnessExercise/.../MuscleCategorySelectionView.swift`**:
   - `@_spi(PersistenceUI) import FitnessPersistenceUI` ergänzen.
   - In `categoryList`: das `Button { ... CategoryTileView(...) }` durch
     `CategoryTileModelView(...)` ersetzen.
   - `workoutId` aus `viewModel.workoutStorageService.currentWorkout?.id`
     pullen (oder als neuen `@ObservationIgnored` Property auf VM exposen
     wenn sauberer). Tile mit `.id("\(workoutId.uuidString)-\(group.rawValue)")`
     versehen — die `@Query`-Re-Init-Boundary aus T6 (§14d).
   - Falls `workoutId` nil ist (kein Workout selected): Fallback rendern
     (alter `CategoryTileView` oder leere Tile). Heutige App garantiert
     in dieser View ein Workout, aber defensive Annahme.
3. **`accessibilityIdentifier(HomeIDs.categoryTile(for: ...))`** auf der
   neuen Tile setzen (UI-Tests dürfen nicht brechen).

### Mutations-Pfade — was bleibt gleich

`onTap` ruft heute `router.navigate(to: .muscleCategory(group))`. Das bleibt
unverändert — die Tile leitet die Navigation weiter, sie macht keine Mutation.

`hasActiveSetForCategory` kommt weiter aus
`viewModel.hasActiveSetForCategory(group)` (Coordinator-State, nicht
SwiftData) — Plain-Bool-Boundary konsistent zu T6.

### Was wird **noch nicht** gelöscht

`viewModel.cardViewModel(for:)`, `viewModel.exercisesByCategory`,
`viewModel.refreshExercises()`, `viewModel.getExerciseCount(for:)` bleiben —
sie werden noch von `allExercisesList` (List-Mode, Phase-3) und vom alten
`MuscleCategoryView` (T7b) genutzt. T8 macht den Cleanup.

### T7a Validation

- Build: `FitnessApp` + alle Packages.
- Tests: `MuscleCategorySelectionViewModelTests` muss grün bleiben (sie
  testen das ViewModel, nicht die View — wir ändern hier nur Render-Pfad).
- **Manuell** auf Simulator: Workout öffnen, Übung completen, zurück zur
  Selection — "X of Y" muss sofort stimmen.

### T7a Commit

`T7a: live-fix Bug 2 by routing CategoryTileModelView through MuscleCategorySelectionView`

ADR-Verweise im Body: ADR-0001, ADR-0002.

---

## T7b — Card-Migration (Bug 1 live fix)

### Reihenfolge der Änderungen

1. **`Packages/FitnessExercise/.../MuscleCategoryView.swift`**:
   - `@_spi(PersistenceUI) import FitnessPersistenceUI` ergänzen
     (Dependency aus T7a schon da).
   - `makeCardContainer(exercise:isEditable:isActiveSetVisible:isResetEnabled:isInProgress:)`
     komplett ersetzen durch einen Aufruf an `ExerciseCardModelView` der
     den `Exercise` per Predicate auf `id == exercise.id` zu einem
     `ExerciseModel` resolved und durch `@Bindable` reicht.
   - **Mutations-Pfade**:
     - `onEdit` callbacks rufen `formViewModel.loadExercise(...)` etc. —
       die brauchen weiter ein `Exercise`-Struct. `ExerciseCardModelView`
       liefert das via `model.toDomain()` (T5-Pattern, schon eingebaut).
     - `onStart` ruft `router.navigate(to: .training(exercise, group))` —
       Plain-Param-Boundary, weiter `Exercise`-Struct.
     - `onReset` ruft `viewModel.resetExercise(exercise)` — weiter
       `Exercise`-Struct.
2. **Issue: `ExerciseCardModelView` braucht `@Bindable model: ExerciseModel`,
   aber in `MuscleCategoryView` haben wir nur den `Exercise`-Struct vom
   ViewModel.** Drei Optionen:
   - **(a)** Neuer Wrapper-View in `FitnessPersistenceUI`:
     `ExerciseCardResolvingView` der per `@Query` den `Exercise.id` zu
     einem `ExerciseModel` resolved und intern `ExerciseCardModelView`
     rendert. **Empfehlung.** Klein, isoliert die Resolution, T8 löscht
     die Boundary wenn `MuscleCategoryViewModel` direkt mit `[ExerciseModel]`
     arbeitet.
   - (b) `MuscleCategoryViewModel` umstellen auf `[ExerciseModel]` — zu groß
     für T7b, gehört in T8.
   - (c) Resolution direkt in `MuscleCategoryView` (mehrere `@Query` in
     einer View) — riecht.
3. **`ExerciseCardResolvingView`** (neu in `FitnessPersistenceUI`):

   ```swift
   @_spi(PersistenceUI)
   public struct ExerciseCardResolvingView: View {
       public let exerciseId: UUID
       public let onEdit: (Exercise, ExerciseEditMode) -> Void
       public let isEditable: Bool
       public let analyticsViewModel: AnalyticsViewModel
       public let activeSetViewModel: ActiveSetViewModel
       public let onStart: ((Exercise) -> Void)?
       public let onReset: ((Exercise) -> Void)?
       public let isActiveSetVisible: Bool
       public let isResetEnabled: Bool
       public let isInProgress: Bool

       @Query private var matches: [ExerciseModel]

       public init(
           exerciseId: UUID,
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
           self.exerciseId = exerciseId
           // ... store all
           let id = exerciseId
           var fd = FetchDescriptor<ExerciseModel>(
               predicate: #Predicate { $0.id == id }
           )
           fd.fetchLimit = 1
           _matches = Query(fd)
       }

       public var body: some View {
           if let model = matches.first {
               ExerciseCardModelView(
                   model: model,
                   // ... pass through
               )
           } else {
               EmptyView()  // model deleted while view active, parent will react
           }
       }
   }
   ```

4. **`MuscleCategoryView.makeCardContainer`** ruft `ExerciseCardResolvingView(exerciseId: exercise.id, ...)`.

### T7b Validation

- Build: `FitnessApp` + alle Packages.
- Tests: `MuscleCategoryViewModelTests` muss grün bleiben.
- Neuer Test in `FitnessPersistenceUITests`:
  `ExerciseCardResolvingViewTests` — Predicate-Logik (Resolution by id,
  empty when missing, live mutation flips through) — analog T6-Pattern.
- **Manuell** auf Simulator: Übung in `TrainingView` completen, `pop()`
  zurück → Card zeigt **sofort** "completed" Variant.

### T7b Commit

`T7b: live-fix Bug 1 by routing ExerciseCardModelView through MuscleCategoryView`

ADR-Verweise im Body: ADR-0001, ADR-0002.

---

## Übergreifende Skill- und Hook-Compliance

Pro Commit:

- `.cursor/skills/reviewing-code-changes/SKILL.md` durchlaufen — Stamp in
  `.cursor/hooks/state/code-changes.stamp.md`.
- `.cursor/hooks/state/test-execution.stamp.md` mit Build- und Test-Resultaten.
- `architecture-documentation.md` synchronisieren (FitnessExercise neue Dependency,
  FitnessPersistenceUI neuer ExerciseCardResolvingView).
- `adr-required.sh` Hook: ADR-0001/0002 in Commit-Body referenzieren.

## Definition of Done (T7 gesamt)

- [ ] T7-0: Build + Tests + Commit. Cycle aufgelöst, alte Sites in
      `FitnessExercise` nutzen `FitnessCore.CardVariant` /
      `FitnessUI.ExerciseCardLayout`.
- [ ] T7a: Build + Tests + Commit. Bug 2 manuell verifiziert.
- [ ] T7b: Build + Tests + Commit. Bug 1 manuell verifiziert.
- [ ] `architecture-documentation.md` reflektiert finale Lage nach T7b.
- [ ] T8 ist klar definiert: ViewModel-Caches löschen, `changeVersion` /
      observation loops löschen, alte `ExerciseCardContainerView` und
      `CategoryTileView` löschen, `MuscleCategorySelectionView.allExercisesList`
      und `TrainingView`-Card auf ModelView umstellen oder löschen.

## Akzeptanzkriterien

- Bug 1 (`MuscleCategoryView` Card-Variant nach Finish) live behoben.
- Bug 2 (`MuscleCategorySelectionView` Tile-Count nach Finish) live behoben.
- Keine Regression in einem der 7 Package-Test-Suites.
- Drei Commits, jeder atomar, jeder einzeln rollback-bar.
