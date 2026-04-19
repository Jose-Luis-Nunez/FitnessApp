# T8 — Legacy-Cleanup: Subtraktive Phase

> **Layer**: Cleanup
> **Vorbedingung**: T7 (alle Pilots integriert, Bugs verifiziert behoben)
> **Blockiert**: —
> **Aufwand**: ~120 min

## Ziel

Alle Reste der alten `changeVersion`+Polling-Architektur löschen. Nach diesem Task gibt es im Code keine Hinweise mehr auf die alte Lösung. `architecture-documentation.md` reflektiert den finalen Stand.

## Was gelöscht wird

### In `Packages/FitnessStorage/Sources/FitnessStorage/ExerciseStorageService.swift`
- `public private(set) var changeVersion: Int = 0`
- Alle `changeVersion &+= 1` Statements
- `@Observable` Marker bleibt **falls** noch andere fachliche Properties beobachtet werden, sonst entfernen

### In `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategorySelectionViewModel.swift`
- `private var storageObservationTask: Task<Void, Never>?`
- Methode `startStorageObservation()` komplett
- `private(set) var cardViewModels: [UUID: ExerciseCardViewModel]` — Cache komplett
- Methode `cardViewModel(for:)`
- `refreshExercises()` — falls nicht mehr von außen aufgerufen
- Verkleinerter VM hält nur noch: Coordinator-State, Navigation-Helpers, `hasActiveSetForCategory`

### In `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategoryViewModel.swift`
- Analoge `startStorageObservation`-Logik löschen
- Falls die ganze Klasse obsolet → ganz löschen

### In `Packages/FitnessExercise/Sources/FitnessExercise/ExerciseCardViewModel.swift`
- `syncExercise(_ exercise: Exercise)` — Methode löschen
- Falls die Klasse nur noch in alten ungelöschten Views verwendet wird, evaluieren ob sie ganz raus kann
- **Bevorzugt**: Klasse ganz löschen wenn keine Konsumenten mehr (alle Card-Konsumenten nutzen `ExerciseCardModelView`)

### In `FitnessApp/Features/Training/TrainingView.swift`
- Komplette Datei löschen (ersetzt durch `TrainingModelView`)
- Routing schon in T7 umgestellt

### In `Packages/FitnessExercise/Sources/FitnessExercise/MuscleCategorySelectionView.swift`
- Komplette Datei löschen (ersetzt durch `MuscleCategorySelectionModelView`)
- Aufrufer in T7 umgestellt

### In `Packages/FitnessExercise/Sources/FitnessExercise/CategoryTileView.swift`
- Datei löschen (ersetzt durch `CategoryTileModelView`)

### In `Packages/FitnessExercise/Sources/FitnessExercise/ExerciseCardContainerView.swift`
- Variant-Resolver bereits in T5 in eigene Datei extrahiert
- Container selbst löschen

### Tests
- `Packages/FitnessExercise/Tests/FitnessExerciseTests/MuscleCategorySelectionViewModelTests.swift`:
  - Komplette Suite "CoordinatorCompletionIntegrationTests" löschen (Mock-Theater laut Postmortem)
  - Verbleibende Tests die `MockCoordinatorCache.bumpVersion()`-Pattern nutzen löschen oder umstellen auf `InMemoryStorageStack`
  - Wenn der ganze ViewModel weg ist, ganze Datei löschen
- `MockExerciseManagement` und `ObservableMockExerciseStorage` löschen falls nicht mehr von Tests benötigt
- T2 `snapshotCardViewModelStaleAfterFinish` (Bug-Marker-Test) löschen

## Schritte

### 1. Verifikation: nichts mehr nutzt die zu löschenden Symbole

```bash
# Vor dem Löschen: wer importiert/nutzt das noch?
rg -n 'changeVersion' Packages FitnessApp --glob '*.swift'
rg -n 'startStorageObservation|syncExercise|cardViewModels\[' Packages FitnessApp --glob '*.swift'
rg -n 'TrainingView\(' FitnessApp Packages --glob '*.swift' | rg -v 'TrainingModelView'
rg -n 'CategoryTileView\(|MuscleCategorySelectionView\(' Packages FitnessApp --glob '*.swift' | rg -v Model
rg -n 'ExerciseCardContainerView' Packages FitnessApp --glob '*.swift'
rg -n 'MockCoordinatorCache|MockExerciseManagement|ObservableMockExerciseStorage' Packages --glob '*.swift'
```

Wenn ein Symbol noch genutzt wird das eigentlich raus soll → erst Aufrufer migrieren.

### 2. Schrittweises Löschen (per Symbol-Block)

In dieser Reihenfolge committen (jeder Schritt build+test grün):

1. `changeVersion` aus `ExerciseStorageService` entfernen
2. `startStorageObservation` aus `MuscleCategorySelectionViewModel` entfernen
3. `cardViewModels`-Cache und `cardViewModel(for:)` entfernen
4. `syncExercise` aus `ExerciseCardViewModel` entfernen, ggf. ganze Klasse
5. `TrainingView.swift` löschen
6. `MuscleCategorySelectionView.swift`, `CategoryTileView.swift`, `ExerciseCardContainerView.swift` löschen
7. Mock-Test-Helfer und Test-Theater-Dateien löschen
8. T2 Bug-Marker-Test löschen

Nach jedem Schritt:
```bash
.cursor/scripts/fast-test.sh
```

### 3. Final Smoke-Verifikation

```bash
# Soll 0 Treffer ergeben:
rg "changeVersion|startStorageObservation|syncExercise" Packages/FitnessExercise/Sources Packages/FitnessStorage/Sources

# Soll 0 Treffer für Snapshot-State-Pattern:
rg '@State\s+private var cardViewModel' FitnessApp Packages --glob '*.swift'
```

### 4. Architektur-Doc final-sync

`Datei: .cursor/references/architecture-documentation.md`

Updates:
- **Feature Map**: TrainingView → TrainingModelView (FitnessPersistenceUI)
- **Services**: `ExerciseStorageService` ohne `changeVersion`-Sektion mehr
- **ViewModels**: `MuscleCategorySelectionViewModel` reduziert (nur Coordinator-State + Navigation)
- **Packages**: FitnessPersistenceUI mit Beschreibung der Verantwortlichkeit
- **Architectural Decisions**: Verweise auf ADR-0001/0002/0003

### 5. Skill-Updates abgleichen

Nach Cleanup nochmal alle T0-Skill-Patches anschauen:
- Sind die `rg`-Patterns noch akkurat? (Sie suchen nach Anti-Patterns die jetzt 0 Treffer haben)
- `ui-state-sync.sh` Hook: synthetisch testen dass er den Pattern noch erkennen würde (z.B. via Test-Diff mit `changeVersion &+= 1`)

### 6. UI-Test (manuell, dokumentiert)

Auf Simulator den vollen Flow nochmal:
- Workout starten
- Übung A (Arme): 3 Sätze, finish → Card sofort completed, Tile-Count sofort runter
- Übung B (Beine): startup, 1 Satz active → Card aktiv, Tile zeigt "active" Marker
- Workout neu wählen → alle Tiles re-fetch korrekt (View-Identity via `.id` greift)
- App killen mid-training → neu starten, Session-State weg (per ADR-0003 erwartet)

### 7. Reviewing-code-changes Skill (Pflicht — viele Löschungen)

Subagent über alle Cleanup-Commits laufen lassen, Stamp schreiben.

### 8. Architektur-Sync-Hook lassen passieren

`adr-required.sh` (Pre-Commit, Check 5 in `.git/hooks/pre-commit`) soll den Cleanup als Architektur-Änderung erkennen und auf ADR-0001/2/3 verweisen lassen. Da T8 viele alte Symbole entfernt **und** ggf. Schema-Konvenienzen verschwinden, prüfen ob auch ADR-0005 als Verweis im Commit-Body aufgeführt sein muss (falls SchemaV1-Reste mit weggeräumt werden).

## Definition of Done

- [ ] Alle 6 Symbol-Bereiche aus "Was gelöscht wird" tatsächlich entfernt
- [ ] `rg "changeVersion|startStorageObservation|syncExercise"` → 0 Treffer in Packages/FitnessExercise/Sources
- [ ] App-Target builds grün
- [ ] Full Test Suite grün
- [ ] Manueller Smoke-Test: beide Original-Bugs sind und bleiben behoben
- [ ] `architecture-documentation.md` reflektiert finalen Stand
- [ ] Reviewing-code-changes Skill final durchlaufen, Stamp geschrieben
- [ ] Stop-Hook prüft alle Pflichten
- [ ] Commit-Message: "T8: remove legacy changeVersion+polling architecture per ADR-0001"

## Akzeptanzkriterien

Repository enthält keine Reste der alten Sync-Architektur mehr. Bei einem zukünftigen
Refactor 4 wäre der Code-Body so klein und klar dass die alte Architektur nicht
"versehentlich" wiederbelebt werden kann. Architektur-Doku, ADRs und Agent-System-
Skills/Rules/Hooks sind alle konsistent mit dem neuen Stand.
