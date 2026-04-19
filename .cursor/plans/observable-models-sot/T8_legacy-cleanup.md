# T8 — Legacy-Cleanup: Inkrementelle subtraktive Phase ✅ COMPLETED (T8a + T8c + T8d)

> **Layer**: Cleanup
> **Vorbedingung**: T7 abgeschlossen (T7-0 Cycle-Break, T7a Tile-Live, T7b Card-Live — beide Original-Bugs verifiziert behoben)
> **Blockiert**: —
> **Aufwand**: ~110-130 min (T8a 40 + T8c 30 + T8d 30 + Validate 10-30)

## Kontext: was hat T7 gelassen?

T7 wurde inkrementell ausgeliefert (statt Big-Bang wie ursprünglich geplant). Das hat
zwei Datenpfade übrig gelassen, die parallel leben:

| Pfad | Quelle | Wo verwendet | Bug-relevant? |
|---|---|---|---|
| **Live (`@Query<ExerciseModel>`)** | SwiftData → `ExerciseCardModelView`, `CategoryTileModelView` | `MuscleCategorySelectionView.categoryList` (T7a), `MuscleCategoryView.exerciseListSection` (T7b) | **Beide Original-Bugs fließen hier** |
| **Snapshot (`changeVersion`+Polling)** | `ExerciseStorageService.changeVersion` → ViewModels-Cache → `ExerciseCardContainerView` | `MuscleCategorySelectionView.allExercisesList` (List-Mode, behoben in T8a), `TrainingView` (Detail-Card, deferred T8b), Edit-Bools (`showStartTraining`, `showReset`) auf VM-Snapshot belassen, Routing-`first(where:)` live in T8c | Routing-Drift: ja (in T8c behoben). Edit-Bools: tolerable Latenz, bewusst belassen. |

T8 räumt die **dead-by-design**-Schuld weg: alle `changeVersion`-Observer feuern noch,
aber das Karten-Rendering liest die VM-Snapshots gar nicht mehr. Das ist nicht nur
CPU-Verschwendung, sondern verletzt ADR-0001 ("Model as UI Source of Truth") solange
zwei Wahrheiten parallel existieren.

## Was T8 NICHT macht (ehemalige Plan-Annahmen, die jetzt falsch sind)

| Verworfene Annahme | Realität nach inkrementellem T7 |
|---|---|
| ~~`TrainingView.swift` löschen — ersetzt durch `TrainingModelView`~~ | `TrainingModelView` existiert nicht. T7-Plan hat das verworfen. View bleibt. |
| ~~`MuscleCategorySelectionView.swift` löschen — ersetzt durch `MuscleCategorySelectionModelView`~~ | Existiert nicht. View ist App-Entrypoint, bleibt. |
| ~~`MuscleCategoryView.swift` löschen~~ | Bleibt. T7b hat nur `exerciseListSection` migriert. |
| ~~`MuscleCategorySelectionViewModel` ggf. ganz löschen~~ | Hostet Coordinator-State, Picker-Routing, Reset-Confirmation, Form-Routing — bleibt unentbehrlich. Schrumpft aber. |
| ~~Alles in einem Big-Bang-Commit~~ | Inkrementell, mit Build+Tests+Commit zwischen jeder Phase. |

## Inkrementelle Phasen

### T8a — `allExercisesList` live binden (~40 min)

**Ziel**: Den noch-nicht-migrierten List-Mode in `MuscleCategorySelectionView` auf
`ExerciseCardModelView` umstellen, analog T7b.

**Geltungsbereich**:
- `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategorySelectionView.swift`
  - `allExercisesList` ViewBuilder
  - `exerciseCard(for:category:)` private helper
  - `allExercisesWithCategory` computed property
- Keine Änderungen an `categoryList` (T7a-Pfad bleibt unangetastet)

**Schritte**:
1. `@Query<ExerciseModel>` mit Predicate auf `workoutId == wid` (ohne Category-Filter
   — wir wollen alle Kategorien) als View-Property in `MuscleCategorySelectionView`.
   Init-Zeit-Lookup `viewModel.currentWorkoutId ?? UUID()` als Sentinel,
   `.id(viewModel.currentWorkoutId)` am Body für Workout-Switch-Rebind.
2. `allExercisesWithCategory` aus `allExercisesModels` ableiten:
   - sortieren nach `(isCompleted, category, sortOrder)` für stabile UI
   - jedes Element trägt seine `MuscleCategoryGroup` (aus `model.category` rehydrated)
3. `exerciseCard(for:category:)` umschreiben auf `ExerciseCardModelView(model:...)`,
   alle 7 Closure-Parameter analog T7b setzen.
4. **Edit-Pfad-Subtilität**: Aktueller Code ruft im `onEdit` `pickerViewModel = MuscleCategoryViewModel(group: category)` mit der **Domain-`Exercise`** auf
   (`exerciseFormViewModel.loadExercise(exerciseToEdit, category: category)`). Wir
   konvertieren am Boundary: `model.toDomain()` → `Exercise`. Dieses Pattern ist die
   gleiche Plain-Param-Boundary wie T5 C1c.

**Validation**:
- `xcodebuild build -scheme FitnessExercise` grün
- `xcodebuild test -scheme FitnessExercise` grün (keine neuen Tests nötig — `cardViewModel(for:category:)` wird in T8d gelöscht, jetzt einfach nicht mehr aufgerufen)
- `scripts/fast-test.sh` parallel grün
- App-Build grün
- Commit: `feat(home): live-bind allExercisesList via ExerciseCardModelView (T8a)`

### T8c — `MuscleCategoryView` Routing live binden (~5 min, IMPLEMENTIERT)

> **Status nach Implementierung**: Scope **bewusst reduziert** vs ursprünglicher Plan.
> Begründung im T8c-Stamp + arch-doc. Die ursprünglich geplante Bool-Migration
> wurde nicht durchgeführt, weil `viewModel.exercises` auch der Backing Store für
> `add`/`updateExercise`/`deleteExercise`/`resetProgress`/`saveExercises` (Form-Path)
> ist und ohne parallele Form-Migration (out of scope) nicht entfernt werden kann.
> Die Bools (`showStartTraining` etc.) sind UI-Affordances, nicht Routing —
> Snapshot-Latenz tolerierbar. Folge: T8d schmaler — `refreshExercises()` bleibt
> als Form-Path Sync.

**Ziel (umgesetzt)**: Eine einzige Routing-Stelle live binden, die sonst in eine
freshly-completed Exercise routen könnte (T7b-Bug-1-Fix wäre umgangen).

**Geltungsbereich (umgesetzt)**:
- `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategoryView.swift`
  - Zeile 298: `viewModel.exercises.first(where: { !$0.isCompleted })` →
    `categoryModels.first(where: { !$0.isCompleted })?.toDomain()`
- Inline-Erläuterungs-Comment der UI-Affordance-vs-Routing-Distinction

**NICHT umgesetzt (mit Begründung im Stamp)**:
- VM-Bool-Migration zu Computed-Properties auf der View
- Entfernen der `viewModel.exercises` Snapshot-Backing-Store
- Entfernen von `refreshExercises()`-Calls in `.onAppear` / `.onChange`

**Validation**:
- iso build + tests grün (FitnessExercise: 108/108, kein Delta)
- parallel + App-Build grün (549/549)
- Commit: `refactor(category): live-route Mini-Menu Start Training via categoryModels (T8c)`

### T8d — Tote Symbole löschen (~30 min, Compiler-driven)

**Ziel**: Alles entfernen, was nach T8a+T8c keinen Aufrufer mehr hat. Reihenfolge
ist Compiler-driven: nach jeder Löschung `xcodebuild` laufen lassen, der nächste
Compile-Fehler zeigt, was als Nächstes geht.

**Geltungsbereich**:

Storage-Schicht (Producer der Snapshots):
1. `Packages/FitnessStorage/Sources/FitnessStorage/ExerciseStorageService.swift`
   - `public private(set) var changeVersion: Int = 0`
   - alle `changeVersion += 1` Statements
2. `Packages/FitnessCore/Sources/FitnessCore/ExerciseStoring.swift`
   - Protocol-Property `var changeVersion: Int { get }`
3. Konformer-Mocks (alle synchron mit-löschen):
   - `Packages/FitnessTestSupport/Sources/FitnessTestSupport/MockExerciseStorage.swift`
   - `Packages/FitnessExercise/Tests/FitnessExerciseTests/MuscleCategoryViewModelTests.swift` (file-private MockExerciseStorage)
   - `Packages/FitnessExercise/Tests/FitnessExerciseTests/MuscleCategorySelectionViewModelTests.swift` (file-private MockExerciseStorage)
   - `Packages/FitnessStorage/Tests/FitnessStorageTests/WorkoutStorageServiceTests.swift` (`bumpVersion()` / Property)
   - `Packages/FitnessStorage/Tests/FitnessStorageTests/TestHelpers.swift`

ViewModel-Schicht (Consumer der Snapshots):

> **Scope-Korrektur nach T8c-Realität**: `viewModel.exercises` und
> `refreshExercises()` **bleiben bestehen** in beiden VMs. Sie sind der Backing
> Store für den Form/Picker-Schreib-Pfad (`add`, `updateExercise`,
> `deleteExercise`, `resetProgress`, `saveExercises`), den T8 nicht migriert.
> `cardViewModels`-Cache und `startStorageObservation`-Polling sind aber tot —
> `cardViewModels` hat keinen Reader mehr (T7b/T8a haben alle Aufrufer migriert),
> und `startStorageObservation`'s einziger Effekt war `cardViewModels[id]?.syncExercise(...)`
> + `refreshExercises()`. Letzteres deckt der Form-Pfad selbst ab via
> `.onAppear`/`.onChange(activeSessions)`.

4. `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategorySelectionViewModel.swift`
   - `private var storageObservationTask: Task<Void, Never>?` LÖSCHEN
   - `private func startStorageObservation()` komplett LÖSCHEN
   - alle Init-Sites, die `startStorageObservation()` rufen, ENTFERNEN
   - `private(set) var cardViewModels: [UUID: ExerciseCardViewModel]` (Cache) LÖSCHEN
   - `public func cardViewModel(for:category:)` LÖSCHEN
   - `public var exercisesByCategory: [MuscleCategoryGroup: [Exercise]]` BEHALTEN solange Form-Pfad sie liest (Recon zur T8d-Zeit nochmal prüfen — falls keine Reader, löschen)
   - `public func refreshExercises()` BEHALTEN (Form-Pfad-Sync)
5. `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategoryViewModel.swift`
   - `private var storageObservationTask` LÖSCHEN
   - `startStorageObservation()` LÖSCHEN
   - `cardViewModels` + `cardViewModel(for:)` LÖSCHEN
   - `hasActiveExercise`, `hasCompletedExercises`, `showStartTraining`, `showReset` BEHALTEN — Mini-Menu-Affordances, snapshot-latenz tolerierbar (T8c-Begründung)
   - `public var exercises: [Exercise]` + `refreshExercises()` BEHALTEN — Form-Pfad-Backing-Store
6. `MuscleCategoryView.swift` `.onAppear { viewModel.refreshExercises() }` /
   `.onChange(of: trainingCoordinator.activeSessions.count) { ... }` BEHALTEN —
   sie speisen den Form-Pfad-Snapshot. Inline-Comment aktualisieren auf "T8d clarified".

UI-Schicht (Consumer von ExerciseCardViewModel):
7. `Packages/FitnessExercise/Sources/FitnessExercise/ExerciseCardViewModel.swift`
   - `public func syncExercise(_ updated: Exercise)` löschen.
   - **Ggf. ganze Klasse löschen** wenn keine Konsumenten mehr (Recon zur T8d-Zeit:
     `ExerciseCardContainerView` initialisiert sie noch. Wenn `TrainingView` der
     einzige Aufrufer von `ExerciseCardContainerView` bleibt (T8b deferred), bleibt
     auch `ExerciseCardViewModel` bestehen. Sonst Klasse löschen.)
8. `Packages/FitnessExercise/Tests/FitnessExerciseTests/ExerciseCardViewModelTests.swift`:
   - "syncExercise" Suite löschen.
   - Falls Klasse ganz weg: ganze Datei löschen.

UI-Schicht (Dead Views):
9. `Packages/FitnessExercise/Sources/FitnessExercise/CategoryTileView.swift`:
   - `struct CategoryTileView` wird nirgends mehr instantiiert (T7a hat alle
     Aufrufer auf `CategoryTileModelView` migriert). **Struct löschen.**
   - `public typealias CategoryTileViewConstants = ExerciseCardLayout` —
     wird noch von `MuscleCategorySelectionView.swift:133` (LazyVStack-Spacing)
     gelesen. Behalten ODER Aufrufer auf `ExerciseCardLayout.CategoryTile.verticalSpacing`
     direkt umstellen (1 Stelle, trivial). Senior-Wahl: **typealias und Helper-Datei
     ganz weg, Aufrufer direkt auf `ExerciseCardLayout` umstellen.**
10. `Packages/FitnessExercise/Sources/FitnessExercise/ExerciseCardContainerView.swift`:
    - Wird noch von `MuscleCategorySelectionView.swift:473` (vor T8a) und
      `TrainingView.swift:62` benutzt. Nach T8a nur noch von `TrainingView`.
    - **NICHT löschen** in T8d. Bleibt bestehen für T8b (deferred).

Sentinel-Tests:
11. `Packages/FitnessStorage/Tests/FitnessStorageTests/CoordinatorPersistsCompletionAfterFinishTests.swift`
    - Bleibt — ist die T2-Invarianten-Suite und schützt gegen Bug-1-Regression.
    - Falls einzelne Tests `changeVersion` direkt prüfen (nicht der Fall laut Recon
      — der Test prüft `model.isCompleted` direkt am SwiftData-Container), nichts tun.

**Validation pro Schritt** (Compiler-driven):
- Nach jedem File-Edit: `xcodebuild build -scheme <package>` grün
- Nach allen Edits: `scripts/fast-test.sh` parallel grün
- Final-Smoke (sollte 0 Treffer geben):
  ```bash
  rg "changeVersion|startStorageObservation|syncExercise|cardViewModels" \
     Packages/FitnessExercise/Sources \
     Packages/FitnessStorage/Sources \
     Packages/FitnessTestSupport/Sources
  ```
  (`refreshExercises` und `viewModel.exercises` bleiben — Form-Pfad-Backing-Store)
- Commit: `chore(cleanup): remove changeVersion+polling architecture (T8d)`

### T8b — DEFERRED: TrainingView-Card-Migration

**Status**: Nicht in T8 enthalten. **Senior-Begründung**:

- `TrainingView` lebt **nur, solange** der Coordinator aktiv ist. Sobald
  `coordinator.finishExercise()` läuft, navigiert die View weg. Der "post-finish
  UI-flip"-Bug (T7b-Fix-Anlass) **kann hier strukturell nicht auftreten** — die
  View existiert nicht mehr, wenn der Bug-Trigger feuert.
- Card hat Active-Set-Animation, Set-Counting, Phasen-Übergänge.
  Bug-Blast-Radius bei Migration ist mittel-hoch.
- ADR-0001 fordert "Model as UI SoT" **pro View-Subtree**, nicht
  "eine View darf keine zwei Datenquellen haben". `TrainingView` ist in sich
  konsistent (Card+ActionBar lesen aus `trainingCoordinator`).
- **Trigger für Aufnahme**: User-Bug-Report im Training-Detail, oder
  Schuld-Audit nach 6 Monaten priorisiert es als Aufräum-Sprint.

Daraus folgen die T8d-Kompromisse:
- `ExerciseCardContainerView.swift` bleibt (für `TrainingView`)
- `ExerciseCardViewModel` bleibt vermutlich (für `ExerciseCardContainerView`)
- `MuscleCategoryViewModel.cardViewModel(for:)` weg, aber Klasse
  `ExerciseCardViewModel` selbst bleibt nutzbar via direktes Init

## Definition of Done — ✅ COMPLETED

- [x] T8a + T8c + T8d implementiert, je Phase ein Commit
- [x] `rg "changeVersion|startStorageObservation|syncExercise" Packages/FitnessExercise/Sources Packages/FitnessStorage/Sources` → 0 Treffer
- [x] Karten-Rendering überall live über `@Query<ExerciseModel>` (außer `TrainingView`-Detail, deferred)
- [x] App-Target builds grün
- [x] Full Test Suite grün
- [x] Manueller Smoke-Test: beide Original-Bugs sind und bleiben behoben
- [x] `architecture-documentation.md` reflektiert finalen Stand:
  - `MuscleCategorySelectionView.allExercisesList` jetzt live (T8a)
  - `ExerciseStorageService` ohne `changeVersion`-Sektion
  - `MuscleCategorySelectionViewModel`/`MuscleCategoryViewModel` reduziert auf
    Coordinator-State + Navigation + Form-Routing
  - `TrainingView` als bewusst zurückgelassene legacy-Stelle dokumentiert
    (mit Verweis auf T8b-DEFERRED-Begründung)
- [x] ADR-0001 / ADR-0002 reflektieren T8b-Deferral mit Begründung
- [x] `reviewing-code-changes` Skill durchlaufen pro Phase, Stamps geschrieben

## Akzeptanzkriterien

Karten-Rendering im **Home/MuscleCategory**-Subtree fließt zu 100% über
`@Query<ExerciseModel>`. `changeVersion`-Architektur ist vollständig entfernt.
Repository enthält keinen toten Snapshot-Cache, keinen toten Polling-Observer.
Die einzige verbleibende `ExerciseCardContainerView`-Verwendung ist `TrainingView`
und ist im Code-Comment + arch-doc + diesem Plan-File als bewusst-zurückgelassen
mit Trigger-Bedingung dokumentiert.

## Nicht-Ziele

- TrainingView-Card-Migration (siehe T8b-DEFERRED)
- Refactor von `ExerciseFormViewModel` (out of scope für SoT-Initiative)
- Neue Features oder Architektur-Tokens
- Rule/Skill/Hook-Updates über das hinaus, was die Cleanup-Validation natürlich
  erfordert (z.B. arch-doc sync ist Pflicht; aber kein neues Skill-Pattern)
