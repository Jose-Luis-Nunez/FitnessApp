# T0b — Mock-Fidelity Skill-Section

> **Layer**: Agent-System Härtung
> **Vorbedingung**: keine
> **Blockiert**: T1 (ADRs)
> **Aufwand**: ~30 min

## Ziel

Verhindern dass Tests "grün" sind weil ihre Mocks die Produktions-Verkabelung verkürzen statt sie zu spiegeln.

## Konkretes Beispiel aus dem Postmortem

`MuscleCategorySelectionViewModelTests.swift` baut den `TrainingCoordinator` direkt mit Closures:

```swift
let coordinator = TrainingCoordinator(
    findCategory: { _ in group },
    onExerciseUpdate: { _, _ in storage?.bumpVersion() },  // <-- BRICHT VERTRAG
    onExerciseReset: { _, _ in }
)
```

Die Produktion (`TrainingCoordinatorCache.swift`) hat ein **anderes Verhalten**:

```swift
let coordinator = TrainingCoordinator(
    findCategory: { _ in group },
    onExerciseUpdate: { [weak self] exercise, category in
        self?.exerciseManagementService.updateExercise(exercise, category: category)
    },
    onExerciseReset: { [weak self] exercise, category in
        self?.exerciseManagementService.resetExercise(exercise, category: category)
    }
)
```

Konsequenz: Tests bestehen `coordinator.finishExercise()` ohne dass jemals `updateExercise` aufgerufen wurde — sie maskieren genau die Bug-Klasse die wir suchen.

## Schritte

### 1. Skill-Section anhängen

`Datei: .cursor/skills/reviewing-test-quality/SKILL.md`

Neue Section **am Ende von Section E** hinzufügen (vor Section F):

```markdown
## E.2 Callback Fidelity (Mock-Vertragsbruch)

Wenn Tests einen Service mit Closure-Parametern direkt instanziieren (statt
über die Produktions-Factory/-Cache), prüfen ob die Test-Closures **alle**
Side-Effects der Produktion mitmachen.

### Smell

```swift
// In Tests:
let coordinator = TrainingCoordinator(
    onExerciseUpdate: { _, _ in storage.bumpVersion() }
)

// In Produktion (TrainingCoordinatorCache):
let coordinator = TrainingCoordinator(
    onExerciseUpdate: { exercise, category in
        managementService.updateExercise(exercise, category: category)  // <-- fehlt im Test
    }
)
```

Der Test "beweist" dass die UI auf `bumpVersion` reagiert — nicht dass
`updateExercise` jemals aufgerufen wird. Bug-Klasse "Schreibweg fehlt"
bleibt unsichtbar.

### Such-Pattern (rg)

Für jede Test-Datei die Service-Closures injiziert:

```bash
# Finde Test-seitige Service-Konstruktoren mit Closures:
rg -n 'TrainingCoordinator\(|XStorageService\(' Packages/*/Tests --glob '*.swift' -A5 \
  | rg -B1 'on\w+: \{'

# Vergleiche mit Produktions-Verkabelung:
rg -n 'TrainingCoordinator\(' Packages/*/Sources --glob '*.swift' -A8
```

Wenn die Test-Closure **weniger** Service-Calls macht als die Produktion → Smell.

### Fix-Optionen

1. **Shared Test-Fixture**: Extrahiere die Produktions-Verkabelung in ein
   Test-Helper-Modul (z.B. `TrainingCoordinatorCache(storage: testStorage,
   management: testManagement)`) und nutze diesen statt manuelle Closures.
2. **Echtes Coordinator-Cache in Tests**: Wenn der Cache `@MainActor` und ohne
   schwere Dependencies ist → in Tests direkt verwenden.
3. **Integration über echten Container**: in-memory `ModelContainer` +
   produktiver `ExerciseManagementService` + `TrainingCoordinatorCache`.

### Akzeptanzkriterium

Jede `on*`-Closure in Test-Setups muss entweder:
- exakt dieselben Service-Calls machen wie das Produktions-Pendant, oder
- ein Kommentar `// MARK: mirrors X.swift line Y` mit Verweis enthalten,
  oder
- über eine Shared-Fixture laufen die das garantiert.

## E.3 State-Pre-Priming (Test schreibt was Produktion schreiben soll)

### Smell

```swift
for _ in 0..<exercise.sets { coordinator.completeSet() }

var completed = exercise
completed.isCompleted = true
mock.exercisesByCategory[.arms] = [completed]  // <-- Test schreibt Endzustand

coordinator.finishExercise()  // <-- Was hier passiert ist egal — Mock ist schon "fertig"

#expect(cardVM.exercise.isCompleted)
```

Der Test prämiert das erwartete Endergebnis ein, bevor der zu testende Aufruf läuft.

### Such-Pattern

```bash
rg -n 'exercisesByCategory\[\..+\]\s*=' Packages/*/Tests --glob '*.swift' -B2 -A5 \
  | rg -B5 'finishExercise\(\)|completeSet\(\)'
```

Jede Sequenz `mock.X = expectedEndState` direkt vor `coordinator.action()` ist verdächtig.

### Fix

Tests dürfen den Domain-Pfad nicht "helfen". Echtes Setup:
```swift
// Vorher: Domain-State wie zu Beginn der Aktion
mock.exercisesByCategory[.arms] = [activeExercise]

// Aktion:
coordinator.finishExercise()

// Nachher: Beobachte Mock-Effekte (welche updateExercise-Calls kamen?)
#expect(mock.updateExerciseCalls.contains { $0.exercise.id == activeExercise.id })
#expect(mock.updateExerciseCalls.last?.exercise.isCompleted == true)
```
```

### 2. Cross-Reference

In `.cursor/skills/reviewing-test-quality/SKILL.md` ganz oben (TOC oder Intro)
Verweis auf E.2 + E.3 ergänzen.

### 3. Reviewer-Subagent-Prompt updaten

`Datei: .cursor/agent-roles/reviewer.md` — neue Bullets:

- Prüfe Mock-Fidelity (Skill E.2)
- Prüfe State-Pre-Priming (Skill E.3)

## Definition of Done

- [ ] Sections E.2 und E.3 in `reviewing-test-quality/SKILL.md` ergänzt
- [ ] Konkrete `rg`-Patterns enthalten
- [ ] Beispiele aus echtem Code zitiert (`MuscleCategorySelectionViewModelTests`)
- [ ] Reviewer-Subagent-Prompt verweist auf neue Sections
- [ ] Commit-Message verweist auf T0b + Plan

## Akzeptanzkriterien

Bei einem zukünftigen Test-Diff der das `bumpVersion()`-Pattern oder das
`mock.X = expected` direkt vor `action()`-Pattern enthält erkennt der Reviewer-Subagent
es per Skill und fordert Fix.
