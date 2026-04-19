# T0e — SwiftData Predicate Anti-Patterns Skill

> **Layer**: Agent-System Härtung
> **Vorbedingung**: keine
> **Blockiert**: T1 (ADRs)
> **Aufwand**: ~30 min

## Ziel

Verhindern dass zukünftige `@Query`/`FetchDescriptor`-Diffs in bekannte SwiftData-Predicate-Bug-Klassen laufen, die in den Reviews konkret identifiziert wurden.

## Bekannte SwiftData-Predicate-Bug-Klassen (aus Reviews)

| Anti-Pattern | Bug-Klasse | Quelle |
|--------------|-----------|--------|
| `$0.relation?.field == X` (Optional-Chain in Predicate) | Historisch broken bis iOS 17.5; heute fragile | Fatbobman, Michael Tsai |
| Mehrstufige Optional-Chains `$0.a?.b?.c == X` | Unsupported predicate runtime crash | Apple Predicate Doc |
| `$0.persistentModelID == capturedID` | Plattform-Verhalten unklar dokumentiert | Spike |
| `@Query` initialisierung ohne View-Identity bei Workout-/Filter-Wechsel | Stale Predicate, View bleibt bei altem Wert | Spike Übergang C |
| `@ModelActor` mutiert + `@Query` im View | Async Update-Lücke (sichtbare Zellen nicht refresht) | Stack Overflow Jan 2026 |
| Force-unwrap in Predicates `$0.relation!.id == X` | Runtime crash | Apple Doc |

## Schritte

### 1. Skill-Section anhängen

`Datei: .cursor/skills/reviewing-code-changes/SKILL.md`

Neue Section am Ende von §13 (oder als §14):

```markdown
## §14 — SwiftData Predicate Anti-Patterns

Bei jedem Diff der `#Predicate` oder `Query(filter:` einführt prüfen:

### Anti-Pattern 1: Optional-Chain in Predicate

```swift
// SCHLECHT
@Query(filter: #Predicate<ExerciseModel> { $0.workout?.id == workoutId })
```

Optional-Chain (`?.`) in `#Predicate` war bis iOS 17.5 broken und ist auch danach
fragile. Multi-Hop (`?.a?.b`) crasht zur Laufzeit mit `unsupportedPredicate`.

**Fix**: denormalisiere die Foreign-Key auf das Kind-Modell:
```swift
@Model class ExerciseModel {
    @Attribute(.indexed) var workoutId: UUID  // <-- denormalisiert
    var workout: WorkoutModel?
}

@Query(filter: #Predicate<ExerciseModel> { $0.workoutId == workoutId })
```

### Anti-Pattern 2: Force-Unwrap in Predicate

```swift
// SCHLECHT — crash bei nil
#Predicate { $0.workout!.id == workoutId }
```

**Fix**: gleiche Lösung wie Anti-Pattern 1 (Denormalisierung).

### Anti-Pattern 3: PersistentIdentifier-Vergleich ohne Tests

```swift
@Query(filter: #Predicate { $0.persistentModelID == capturedID })
```

Funktioniert in der Praxis, ist aber **nicht klar dokumentiert** in Apple's
SwiftData-Refs. Risiko bei OS-Updates.

**Empfehlung**: Wenn `@Model` ein `@Attribute(.unique) var id: UUID` hat (wie
`ExerciseModel`), nutze `id == X` — robuster und in dieser Codebase bereits
validiert (siehe `ExerciseStorageService`).

### Anti-Pattern 4: @Query ohne View-Identity bei dynamischem Filter

```swift
struct CategoryTileView: View {
    let workoutId: UUID  // ändert sich bei Workout-Wechsel
    @Query private var exercises: [ExerciseModel]
    init(workoutId: UUID) {
        self.workoutId = workoutId
        _exercises = Query(filter: #Predicate { $0.workoutId == workoutId })  // <-- captured beim init
    }
}

// Parent:
ForEach(categories) { CategoryTileView(workoutId: currentWorkoutId) }
// ^ wenn currentWorkoutId wechselt, View wird NICHT neu identifiziert → alter Predicate
```

**Fix**: View-Identity erzwingen via `.id(workoutId)`:
```swift
ForEach(categories) {
    CategoryTileView(workoutId: currentWorkoutId)
        .id(currentWorkoutId)  // <-- View komplett neu beim Wechsel
}
```

### Anti-Pattern 5: Mutation via @ModelActor während @Query in View

```swift
@ModelActor actor BackgroundUpdater {
    func updateAll() async {
        // mutates ExerciseModel instances
        try? modelContext.save()
    }
}
```

`@Query` im MainActor-View bekommt **nicht zuverlässig** ein Update wenn die
Mutation in einem anderen Context+Actor passierte (siehe SO Jan 2026).

**Fix**:
- Default: alles `@MainActor` lassen, einen `ModelContext` (siehe ADR-001)
- Wenn Background-Mutation nötig: nach Save explizites Refresh-Signal in MainActor-Context

### Such-Pattern für Reviewer

```bash
# Anti-Pattern 1 + 2 (Optional/Force-Chain in Predicate):
rg -n '#Predicate' --glob '*.swift' -A2 | rg '\?\.|\!\.' --colors

# Anti-Pattern 3 (PersistentIdentifier):
rg -n 'persistentModelID\s*==' --glob '*.swift'

# Anti-Pattern 4 (dynamischer Filter ohne .id):
rg -n '@Query' --glob '*.swift' -A5 | rg 'filter:.*captured|let.*=.*self\.'
# Manuelle Prüfung: erscheint diese Variable im Parent in einer ForEach ohne .id?

# Anti-Pattern 5 (@ModelActor):
rg -n '@ModelActor' --glob '*.swift'
```

### Akzeptanzkriterium

Jeder Diff der `#Predicate` einführt MUSS:
- Keine `?.` oder `!.` Patterns enthalten ODER explizit kommentieren warum sicher
- Wenn dynamischer Filter: View-Identity per `.id()` im Parent garantieren
- Bei `@ModelActor`-Mutation: ADR (siehe T0d) der den MainActor-Bypass begründet
```

### 2. Reviewer-Subagent

`Datei: .cursor/agent-roles/reviewer.md` Bullet ergänzen:

- Prüfe §14 (SwiftData Predicate Anti-Patterns) bei jedem Diff der `#Predicate` einführt

### 3. (Optional) Hook-Warning

`Datei: .cursor/hooks/checks/code-validation.sh` — neue Warning-Sektion:

```bash
# Predicate Anti-Patterns warning (T0e)
predicate_warn() {
    local diff
    diff=$(git diff --cached --diff-filter=AM -- '*.swift' 2>/dev/null) || return 0
    # Optional-Chain in Predicate (rough heuristic)
    if echo "$diff" | rg -q '^\+.*#Predicate' ; then
        if echo "$diff" | rg -A3 '^\+.*#Predicate' | rg -q '\?\.|\!\.' ; then
            echo "WARN [T0e]: Predicate diff contains optional/force chain (?.  or !.)"
            echo "  Skill: .cursor/skills/reviewing-code-changes/SKILL.md §14 Anti-Pattern 1-2"
        fi
        if echo "$diff" | rg -q 'persistentModelID\s*==' ; then
            echo "WARN [T0e]: Predicate uses persistentModelID — prefer 'id == UUID' if available"
        fi
    fi
    return 0
}
predicate_warn
```

## Definition of Done

- [ ] §14 in `reviewing-code-changes/SKILL.md` ergänzt mit allen 5 Anti-Patterns
- [ ] Reviewer-Subagent-Prompt erweitert
- [ ] Hook-Warning aktiv (nicht blocking)
- [ ] Commit-Message verweist auf T0e + Plan

## Akzeptanzkriterien

Bei einem zukünftigen Diff der `#Predicate { $0.workout?.id == X }` einführt
warnt der Hook und der Reviewer-Subagent fordert Denormalisierung oder ADR.
