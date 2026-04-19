# 0003 — Training Coordinator Session-State ist non-persistent und blocking

* Status: accepted
* Date: 2026-04-19
* Deciders: jose.nunez

## Kontext

`TrainingCoordinator.activeSessions[id].currentExercise` ist heute eine
`Exercise`-struct-Kopie, gehalten während einer aktiven Trainingseinheit.

Mit ADR-0001 (`@Model` als UI-SoT) entsteht ein potenzieller Konflikt bei
parallelen Mutationen:

- User startet Training für Exercise X. Coordinator hält einen Snapshot mit z.B.
  `sets = 3` zum Session-Start.
- User editiert Exercise X parallel im Edit-Sheet. Mutation auf `@Model`-Instanz:
  `model.sets = 5`. SwiftData speichert → `@Query` und `@Bindable`-Views sehen
  sofort `5`. Aber:
- Was gilt für die laufende Session? Coordinator-Snapshot mit `sets = 3` (User
  startete vor dem Edit) oder die neue `@Model`-Wahrheit mit `sets = 5`?

Beide naive Lösungen führen zu Bugs:

- **Snapshot ignorieren / live `@Model` lesen** → Sätze die der User schon
  abgeschlossen hat können plötzlich aus dem geplanten Set fallen oder
  doppelt erscheinen.
- **Snapshot überschreiben** → User-Edits während Session werden für die
  Session verworfen, ohne dass die UI das kommuniziert.

## Optionen

- **A**: Coordinator beobachtet `@Model`-Mutationen und merged sie in laufende
  Session (komplex, Race-anfällig, schwer zu testen)
- **B**: UI **blockiert** Edit-Operationen auf Exercise X während aktiver
  Session (Edit-Button disabled, Sheet wird verweigert mit Hinweis)
- **C**: Coordinator hält `PersistentIdentifier` statt struct-Kopie, liest
  jeden Frame live aus `@Model` — Mutations propagieren transparent (SwiftData
  Observation handelt Updates)
- **D**: Status quo — keine Garantie, dokumentiertes "don't do that"

## Entscheidung

**Option B als Hauptregel + Konvention C-Light für Coordinator-Interna**:

### 1. UI-Edit-Block während aktiver Session

Solange `coordinator.activeSessions[exerciseId]` existiert:

- Edit-Button auf Exercise X **disabled** in allen Konsumenten-Views
  (List, Detail, Card)
- Edit-Sheet öffnet nicht (Tap zeigt kurzes Banner "Übung läuft — Bearbeitung
  nach Trainingsende möglich")
- Reset / Delete von Exercise X ebenfalls blockiert während Session

### 2. Coordinator-State ist non-persistent

`activeSessions`, `ActiveSetViewModel.completedSetCount`, Timer-State sind
**explizit ephemer**:

- Bei App-Kill mid-training **geht der Session-Fortschritt verloren** (wie
  heute schon — kein Regress).
- Keine SwiftData-Persistenz dieser Felder. Sie sind reine Live-Session-State.
- Bei App-Foreground nach Backgrounding wird die Session bei kurzer Pause
  fortgeführt (existing behaviour), bei langer Pause könnte ein zukünftiger
  Mechanismus Foreground-Sync triggern (out of scope hier).

### 3. Coordinator hält fachlich-relevante Felder als struct-Kopie

- Der Coordinator behält `currentExercise: Exercise` als struct beim
  Session-Start (was er heute tut). Set-Plan ist zur Session-Zeit gefroren.
- Persistierte Set-Resultate werden direkt auf `ExerciseModel` geschrieben
  (über `FinishExerciseUseCase`: `model.isCompleted = true; context.save()`).
- Coordinator referenziert die `@Model`-Identität via `id: UUID` (das DTO und
  das Model teilen denselben `id`), aber liest den Plan nicht live aus dem
  Model — das ist genau die Snapshot-Garantie des Edit-Blocks.

## Konsequenzen

### Positiv

- Edit-while-Training-Race **ausgeschlossen by construction**.
- Coordinator bleibt schlank, fachlich klar abgegrenzt von der Persistenz.
- Persistenz-Pfad eindeutig: alle persistierten Set-Mutationen laufen über
  `@Model` + `context.save()`. Eine einzige Schreibrichtung.
- Tests können den Coordinator weiterhin mit struct-`Exercise` setupen, ohne
  einen `ModelContainer` zu brauchen (Coordinator-Tests bleiben schlank).

### Negativ

- UI muss Edit-Block-State bereitstellen — neuer State-Computed in den
  Konsumenten-Views (Edit-Button-`isEnabled`-Logik).
  Mehrarbeit konzentriert in T7 (`TrainingModelView`-Pilot).
- App-Kill mid-training verliert Session-Progress. **Akzeptiert** und
  in Onboarding/UX dokumentieren (zukünftige Ticket-Karte für persistente
  Session falls User-Feedback es fordert).

### Neutral

- `Exercise`-struct in `FitnessCore` bleibt — sie ist die Coordinator-Plan-DTO.
- `ExerciseModel` wird die UI-Quelle (ADR-0001), aber der Coordinator hält
  sie nicht direkt. Klare Schichtentrennung: Coordinator → struct,
  UI → @Model.

## Verweise

- ADR-0001 (`@Model` als UI-SoT — begründet warum Coordinator-Snapshot
  potenzielles Konfliktrisiko hatte)
- ADR-0002 (`FitnessPersistenceUI` — wo die Edit-Block-Views leben würden)
- T7 (TrainingModelView implementiert Edit-Block in der Pilot-View)
- T8 (Legacy-Cleanup berücksichtigt Coordinator-Vertrag)
