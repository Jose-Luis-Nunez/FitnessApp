# T0c — Snapshot `@State` Smell in Code-Review-Skill

> **Layer**: Agent-System Härtung
> **Vorbedingung**: keine
> **Blockiert**: T1 (ADRs)
> **Aufwand**: ~20 min

## Ziel

Die exakte Bug-Klasse von Bug 1 (`TrainingView` mit `@State private var cardViewModel`) als Smell-Pattern im Code-Review-Skill verankern, damit zukünftige Diffs die das Pattern wiederholen einen Review-Trigger auslösen.

## Bug-Klasse (Bug 1 als Beispiel)

```swift
// FitnessApp/Features/Training/TrainingView.swift
struct TrainingView: View {
    @State private var cardViewModel: ExerciseCardViewModel  // <-- Snapshot beim init

    init(exercise: Exercise, ...) {
        self._cardViewModel = State(wrappedValue: ExerciseCardViewModel(exercise: exercise) { ... })
        // ^^^ Exercise wird hier "eingefroren". Nach finishExercise() bleibt cardViewModel.exercise stale.
    }
}
```

Gleichzeitig existiert in **derselben** App eine zweite Quelle für dieselbe Exercise-ID:
```swift
// MuscleCategorySelectionViewModel
private(set) var cardViewModels: [UUID: ExerciseCardViewModel] = [:]
```

Zwei Quellen für **dieselbe Domain-ID** mit **unterschiedlichem Lifecycle** = Sync-Bug garantiert.

## Schritte

### 1. Skill erweitern

`Datei: .cursor/skills/reviewing-code-changes/SKILL.md`

In Section 13 (oder wo `@State`/`@Observable` diskutiert wird) neue Sub-Section anhängen:

```markdown
## §13d — Duplicate Domain-State Holders

### Smell

Eine View hält ein `@State`-`ViewModel`, das eine Domain-Entität (mit eindeutiger
ID) spiegelt — und **dieselbe ID** wird woanders (anderer ViewModel-Cache, anderer
View-`@State`) ebenfalls gehalten.

```swift
// View A:
struct TrainingView: View {
    @State private var cardViewModel: ExerciseCardViewModel  // exercise mit ID X

// View B (via VM-Cache):
@Observable class MuscleCategorySelectionViewModel {
    var cardViewModels: [UUID: ExerciseCardViewModel]  // enthält evtl. ID X
}
```

Konsequenz: Mutation an einer Stelle propagiert nicht automatisch zur anderen. Ein
`syncExercise(...)` Workaround ist Symptom, nicht Lösung.

### Such-Pattern

```bash
# Finde @State VMs in Views:
rg -n '@State\s+private\s+var\s+\w*ViewModel' FitnessApp Packages --glob '*.swift'

# Finde gleichzeitig VM-Caches mit UUID-Key:
rg -n 'var\s+\w*ViewModels\s*:\s*\[UUID' Packages --glob '*.swift'
```

Beide Treffer im selben PR/Diff = Review-Trigger.

### Akzeptierte Pattern (Fix-Optionen)

1. **Single Source via @Bindable**:
   ```swift
   @Bindable var model: ExerciseModel  // SwiftData @Model — eine Identität, ein Lifecycle
   ```
2. **Single Source via @Environment**:
   ```swift
   @Environment(MuscleCategorySelectionViewModel.self) var selectionVM
   var card: ExerciseCardViewModel { selectionVM.cardViewModels[id]! }
   ```
3. **Pure rendering**: View nimmt `Exercise` als `let`, keine `@State`-VM:
   ```swift
   struct TrainingView: View {
       let exercise: Exercise  // wird vom Parent neu geliefert wenn sich was ändert
   }
   ```

### Akzeptanzkriterium für Reviewer

Wenn ein Diff `@State private var XViewModel` einführt UND es schon einen
VM-Cache für denselben Entity-Typ gibt, MUSS der Reviewer:
- ein ADR oder Kommentar fordern der erklärt warum zwei Lifecycles OK sind, ODER
- eine der Fix-Optionen vorschlagen.
```

### 2. Hook-Reminder (heuristisch, nicht blocking)

`Datei: .cursor/hooks/checks/code-validation.sh` — am Ende eine **warnende** (nicht
blockierende) Sektion:

```bash
# Duplicate Domain-State Holder warning (T0c)
duplicate_state_warn() {
    local diff
    diff=$(git diff --cached --diff-filter=AM -- '*.swift' 2>/dev/null) || return 0
    local has_state_vm cache_exists
    has_state_vm=$(echo "$diff" | rg -c '^\+.*@State\s+private\s+var\s+\w*ViewModel' || true)
    cache_exists=$(rg -c 'var\s+\w*ViewModels\s*:\s*\[UUID' Packages 2>/dev/null | wc -l | tr -d ' ')
    if [ "${has_state_vm:-0}" -gt 0 ] && [ "${cache_exists:-0}" -gt 0 ]; then
        echo "WARN [T0c]: New @State ViewModel introduced; UUID-keyed VM cache exists elsewhere."
        echo "  Skill: .cursor/skills/reviewing-code-changes/SKILL.md §13d"
        echo "  Action: Confirm single-source-of-truth or document exception in commit body."
    fi
    return 0
}
duplicate_state_warn
```

### 3. Reviewer-Subagent-Prompt

`Datei: .cursor/agent-roles/reviewer.md` Bullet ergänzen:

- Prüfe §13d (Duplicate Domain-State Holders)

## Definition of Done

- [ ] §13d in `reviewing-code-changes/SKILL.md` ergänzt
- [ ] Hook-Warning in `code-validation.sh` aktiv
- [ ] Reviewer-Subagent-Prompt erweitert
- [ ] Commit-Message verweist auf T0c + Plan

## Akzeptanzkriterien

Ein Diff der ein neues `@State private var XViewModel` einführt während ein
`[UUID: XViewModel]`-Cache schon existiert löst eine Hook-Warnung aus und der
Reviewer-Subagent fordert ADR oder Refactor.
